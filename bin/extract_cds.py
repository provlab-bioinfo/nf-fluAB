import argparse
import csv
from collections import defaultdict
import re
from csv import DictReader
__author__ = 'Xiaoli Dong'
__version__ = '0.1.0'
__maintainer__ = 'Xiaoli Dong'
__email__ = 'xiaoli.dong@albertaprecisionlabs.ca'
__status__ = 'Dev'

def extract_cds_from_fasta(fasta, metadata_dict, cds_coords, minlen, maxlen, maxambigs):

    with open(fasta, 'r') as file:    
        header = None
        sequence_lines = []
        
        for line in file:
            line = line.strip()
            if line.startswith('>'):
                if header:
                    # Save the last sequence
                    # remove all the whitespace characters (space, tab, newlines)
                    sequence = ''.join(sequence_lines)
                    extract(header, sequence, metadata_dict, cds_coords, minlen, maxlen, maxambigs)
                   
                       
                header = line[1:]  # Remove the '>' character
                sequence_lines = []
            else:
                sequence_lines.append(line)
        
        # Save the last sequence
        if header:
            sequence = ''.join(sequence_lines)
            extract(header, sequence, metadata_dict, cds_coords, minlen, maxlen, maxambigs)
def extract(header, sequence, metadata_dict, cds_coords, minlen, maxlen, maxambigs):
    
    allowed_bases=['A','T','G','C']
    seqid = header.split()[0]
    seqid_no_ver = seqid.split('.')[0]
    subseq=''

    if seqid in cds_coords:
        coord = cds_coords[seqid]
        pattern = r'^(\d+?)\..(\d+?)\:([+-])'
        match = re.search(pattern, coord)
        seq_from = int(match.group(1))
        seq_to = int(match.group(2))
        strand = match.group(3)

        if strand == '-':
            start_index = seq_to -1
            end_index = seq_from
            
        elif strand == '+':
            start_index = seq_from -1
            end_index = seq_to

        subseq = sequence[start_index:end_index]
        total_atcg_count = len([b for b in subseq if b in allowed_bases])
        subseq_len = len(subseq)

        if (subseq_len - total_atcg_count) <= maxambigs  and subseq_len >= minlen and subseq_len <= maxlen:
            print(">" + seqid_no_ver + " " + metadata_dict[seqid_no_ver] + "|" + str(subseq_len))
            print(subseq)


def parseSGM(sgm):
    
    cds_coord_pass = defaultdict(str)
    pattern = r'^\d+\.1\.1\s+.*'
   
    with open (sgm, 'r+') as in_f:
      
        for line in in_f:

            match = re.search(pattern, line)
            if match:
                #print("Pattern found:", match.group())
                line_list = line.split()
                seq_from = line_list[10]
                seq_to = line_list[11]
                strand = line_list[15]
                trc = line_list[16]

                pf = line_list[3]
                seq_name = line_list[1]

                if trc == 'no' and pf == 'PASS':
                    #print(line)
                    cds_coord_pass[seq_name] = seq_from + '..' + seq_to + ':' + strand
    return cds_coord_pass
               
def reformat_bvbrc_csv(bvbrc):

    metadata = defaultdict(str)

    segid2gname = {"1": "PB2", "2": "PB1", "3": "PA", "4": "HA", "5": "NP",  "6": "NA", "7": "M", "8": "NS"}
     
    gname2segid = {"PB2": "1","PB1": "2","PA": "3", "HA": "4", "NP": "5",  "NA": "6", "M": "7", "NS": "8"}
    
    keys_to_include = [
            'GenBank Accessions', 
            'Host Common Name', 
            'Segment', 
            'Protein',
            'Subtype', 
            'Isolation Country', 
            'Strain',  
            'H1 Clade Global',
            'H1 Clade US',
            'H5 Clade'
    ]

    #print(*keys_to_include, sep="\t")

    with open(bvbrc, 'r') as f:

        dict_reader = DictReader(f)
        
        
        for row in dict_reader:
            
            extracted_columns = []
            
            if row['Host Common Name'] in ["Patent"]:
                continue
            if row['Segment'] not in list(segid2gname.keys()) + list(gname2segid.keys()):
                continue
           
            subset_row_dict = dict(filter(lambda item: item[0] in keys_to_include, row.items()))

            # in bvrc file, some of the entries is using gene name as segment id, fix it
            if row['Segment'] in list(gname2segid.keys()):
                subset_row_dict['Segment'] = gname2segid[row['Segment']]
            
            subset_row_dict['Protein'] = segid2gname[subset_row_dict['Segment']]
            

            #some of the segment in the table are using protein name.
            for x in keys_to_include:
                extracted_columns.append(subset_row_dict[x])

            extracted_columns = [x.replace(' ', "_") for x in extracted_columns]
            extracted_columns = ['na' if x == '' else x for x in extracted_columns]
            #print(extracted_columns[0], '|'.join(extracted_columns[1:]))
            metadata[extracted_columns[0]] = '|'.join(extracted_columns[1:])

            #print(*extracted_columns, sep="\t")
    return metadata

# Initialize parser
parser = argparse.ArgumentParser()

# Adding optional argument
parser.add_argument("-f", "--fasta", help = "fasta", required=True)
parser.add_argument("--minlen", type=int, default=700, help = "min sequence length", required=False)
parser.add_argument("--maxlen", type=int, default=3000, help = "max sequence length", required=False)
parser.add_argument("--maxambigs", type=int, default=0, help = "max number of ambigs bases", required=False)
parser.add_argument("--sgm", help = "sgm output from vadr program", required=True)
parser.add_argument("--bvbrc", help = "bvbrc csv file", required=True)


# Read arguments from command line
args = parser.parse_args()

#read bvbrc-genome metadata
metadata_dict = reformat_bvbrc_csv(args.bvbrc)

cds_coord_pass = parseSGM(args.sgm)

extract_cds_from_fasta(args.fasta, metadata_dict, cds_coord_pass, args.minlen, args.maxlen, args.maxambigs)

