/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    VALIDATE INPUTS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
def valid_params = [
    nanopore_reads_mapping_tools : ['minimap2']
]
def summary_params = NfcoreSchema.paramsSummaryMap(workflow, params)

// Validate input parameters
WorkflowNanopore.initialise(params, log, valid_params)

// TODO nf-core: Add all file path parameters for the pipeline to the list below
// Check input path parameters to see if they exist
//def checkPathParamList = [ params.input, params.multiqc_config, params.fasta ]
//def checkPathParamList = [ params.input]
def checkPathParamList = [ 
    params.input, 
    params.hostile_human_ref_minimap2, 
    params.flu_primers, 
    params.typing_db, 
    params.flu_db_msh, 
    params.flu_db_fasta,
    params.clair3_variant_model,
    params.nextclade_dataset_base
]
for (param in checkPathParamList) { if (param) { file(param, checkIfExists: true) } }

// Check mandatory parameters
if (params.input) { ch_input = file(params.input) } else { exit 1, 'Input samplesheet not specified!' }


/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
//
// SUBWORKFLOW: Consisting of a mix of local and nf-core/modules
//
include {
    INPUT_CHECK
} from '../subworkflows/local/input_check'

include {
    PREPARE_REFERENCES
} from '../subworkflows/local/prepare_references'

include {
    QC_NANOPORE
} from '../subworkflows/local/qc_nanopore'

include {
    GETREF_BY_MASH
} from '../subworkflows/local/get_references'

include {
    MAPPING_NANOPORE
} from '../subworkflows/local/mapping_nanopore'

include {
    PREPROCESS_BAM
} from '../subworkflows/local/preprocess_bam'

include {
    CLASSIFIER_BLAST;
    CLASSIFIER_NEXTCLADE;
} from '../subworkflows/local/classifier'


include {
    VARIANTS_NANOPORE;
} from '../subworkflows/local/variants_nanopore'

include {
    CONSENSUS
} from '../subworkflows/local/consensus'


/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// MODULE: Installed directly from nf-core/modules
//
include {
    CUSTOM_DUMPSOFTWAREVERSIONS
} from '../modules/nf-core/custom/dumpsoftwareversions/main'

include {
    CSVTK_CONCAT as CONCAT_CONSENSU_REPORT;
} from '../modules/nf-core/csvtk/concat/main'

include {
    BEDTOOLS_GENOMECOV as BEDTOOLS_GENOMECOV_LOWDEPTH;
} from '../modules/nf-core/bedtools/genomecov/main.nf'

//
// MODULE: developed locally 
//
include {
    CONSENSUS_REPORT
} from '../modules/local/consensus/report/main'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// Info required for completion email and summary
def multiqc_report = []

workflow NANOPORE {

    ch_versions = Channel.empty()

    // SUBWORKFLOW: prepare reference databases ...
    //
    PREPARE_REFERENCES ()
    ch_versions = ch_versions.mix(PREPARE_REFERENCES.out.versions)

    //
    // SUBWORKFLOW: Read in samplesheet, validate and stage input files
    //
    INPUT_CHECK (ch_input)
    ch_versions = ch_versions.mix(INPUT_CHECK.out.versions)

    nanopore_reads = INPUT_CHECK.out.longreads
    //nanopore_reads.view()

    /*
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        sequence quality control
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    */
    if(!params.skip_nanopore_reads_qc){
        QC_NANOPORE(
            nanopore_reads,
            PREPARE_REFERENCES.out.ch_hostile_ref_minimap2
        )
        ch_versions = ch_versions.mix(QC_NANOPORE.out.versions)
        QC_NANOPORE.out.qc_reads
            .filter {meta, reads -> reads.size() > 0 && reads.countFastq() > 0}
            .set { nanopore_reads }
      
    }

     /*
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        Identify the closely related rerference through mash
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    */
    GETREF_BY_MASH(
        nanopore_reads, 
        PREPARE_REFERENCES.out.ch_flu_db_msh, 
        PREPARE_REFERENCES.out.ch_flu_db_fasta
    )
    ch_versions.mix(GETREF_BY_MASH.out.versions)
    ch_screen = GETREF_BY_MASH.out.screen
    ch_fasta_fai = GETREF_BY_MASH.out.fasta_fai
    ch_header = GETREF_BY_MASH.out.header

    /*
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
         Map reads to the identified references
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    */
    nanopore_reads.join(ch_fasta_fai).multiMap{
        it ->
            nanopore_reads: [it[0], it[1]]
            fasta: [it[0], it[2]]
    }.set{
        ch_input
    }

    MAPPING_NANOPORE(
        ch_input.nanopore_reads,
        ch_input.fasta
    )
    ch_versions.mix(MAPPING_NANOPORE.out.versions)
    

    /*
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        filter out secondary, supplementary, duplicates, and keep soft/hard clipped alignments
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    */
    MAPPING_NANOPORE.out.bam_bai.join(ch_fasta_fai).join(ch_header).multiMap{
        it ->
            bam_bai: [it[0], it[1], it[2]]
            fasta_fai: [it[0], it[3], it[4]]
            header: [it[0], it[5]]
    }.set{
        ch_input
    }
    PREPROCESS_BAM(ch_input.bam_bai, ch_input.fasta_fai, ch_input.header)

    ch_versions.mix(PREPROCESS_BAM.out.versions)

    /*
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        variant calling
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    */
    
    PREPROCESS_BAM.out.bam_bai.join(ch_fasta_fai).multiMap{
            it ->
                    bam_bai: [it[0], it[1], it[2]]
                    fasta_fai: [it[0], it[3], it[4]]
            }.set { ch_input }
    VARIANTS_NANOPORE(ch_input.bam_bai, ch_input.fasta_fai)
    ch_versions.mix(VARIANTS_NANOPORE.out.versions)

    

    /*
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    consensus generrating
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    */
   
    //produce bed file for the low depth region
    ch_input = PREPROCESS_BAM.out.bam_bai
        .map{
            it -> [it[0], it[1], 1] //[meta, bam, scale]
        }

        //bed file of the low depth regions < params.mindepth
    BEDTOOLS_GENOMECOV_LOWDEPTH(ch_input, [], "bed") 
    

    VARIANTS_NANOPORE.out.vcf_tbi.join(ch_fasta_fai)
        .join(BEDTOOLS_GENOMECOV_LOWDEPTH.out.genomecov)
        .multiMap{
            it ->
                vcf_tbi: [it[0], it[1], it[2]]
                fasta: [it[0], it[3]]
                mask: [it[0], it[5]]
        }.set{
            ch_input
        }

    //ch_input.vcf.view()
    CONSENSUS(ch_input.vcf_tbi, ch_input.fasta, ch_input.mask)
    ch_versions.mix(CONSENSUS.out.versions)
    
    /*
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Typing consensus
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    */
    
    CLASSIFIER_BLAST(CONSENSUS.out.fasta, PREPARE_REFERENCES.out.ch_typing_db)
    ch_versions.mix(CLASSIFIER_BLAST.out.versions)

    CONSENSUS.out.fasta.join(CLASSIFIER_BLAST.out.tsv).multiMap{
        it ->
            consensus: [it[0], it[1]]
            tsv: [it[0], it[2]]
    }.set{
        ch_input
    }
    //ch_input.consensus.view()
    CLASSIFIER_NEXTCLADE(ch_input.consensus, ch_input.tsv)
    ch_versions.mix(CLASSIFIER_NEXTCLADE.out.versions)

     /*
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    producce consensus report
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    */
    /*
    left  = Channel.of( ['X', 1], ['Y', 2], ['Z', 3], ['P', 7] )
    right = Channel.of( ['Z', 6], ['Y', 5], ['X', 4] )
    left.join(right, remainder: true).view()
    */

    
    ch_nextclade_dbname = CLASSIFIER_NEXTCLADE.out.dbname.groupTuple()//.view()
    ch_nextclade_tsv = CLASSIFIER_NEXTCLADE.out.tsv.map{
        meta, tsv ->
            meta.remove("seqid")
            [meta, tsv]  
    }.groupTuple().ifEmpty([])//.view()

    ch_screen
        .join(CONSENSUS.out.stats.ifEmpty([]), remainder: true)
        .join(PREPROCESS_BAM.out.coverage.ifEmpty([]), remainder: true)
        .join(CLASSIFIER_BLAST.out.tsv.ifEmpty([]), remainder: true)
        .join(ch_nextclade_tsv.ifEmpty([]), remainder: true)
        .join(ch_nextclade_dbname.ifEmpty([]), remainder: true)
        .multiMap{
            it -> 
                screen: it[1] ? [it[0], it[1]] : [it[0], null]
                stats: it[2] ? [it[0], it[2]] : [it[0], null]
                cov: it[3] ? [it[0], it[3]] : [it[0], null]
                typing: it[4] ? [it[0], it[4]] : [it[0], null]
                nextclade_tsv: it[5] ? [it[0], it[5].join(',')] : [it[0], null]
                nextclade_dbname: it[6] ? [it[0], it[6].join(',')]: [it[0], null]
                dbver: [it[0], params.flu_db_ver]
        }.set{
            ch_input
        }
    //ch_input.stats.view()
    CONSENSUS_REPORT(
        ch_input.stats, 
        ch_input.cov, 
        ch_input.typing, 
        ch_input.nextclade_tsv, 
        ch_input.nextclade_dbname, 
        ch_input.screen,  
        ch_input.dbver
    ) 
    
    CONCAT_CONSENSU_REPORT(
        CONSENSUS_REPORT.out.csv.map { cfg, stats -> stats }.collect()//.view()
            .map{
                files ->
                    tuple(
                        [id: "${params.nanopore_reads_mapping_tool}-${params.nanopore_variant_caller}"],
                        files
                    )
        },
        "csv",
        "csv"
    )  
    CUSTOM_DUMPSOFTWAREVERSIONS (
        ch_versions.unique().collectFile(name: 'collated_versions.yml')
    )

}


/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    COMPLETION EMAIL AND SUMMARY
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow.onComplete {
    if (params.email || params.email_on_fail) {
        NfcoreTemplate.email(workflow, params, summary_params, projectDir, log, multiqc_report)
    }
    NfcoreTemplate.summary(workflow, params, log)
    if (params.hook_url) {
        NfcoreTemplate.adaptivecard(workflow, params, summary_params, projectDir, log)
    }
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
