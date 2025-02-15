//
// This file holds several functions specific to the workflow/influenza.nf in the nf-core/influenza pipeline
//

import groovy.text.SimpleTemplateEngine

class WorkflowIllumina {

    //
    // Check and validate parameters
    //
    public static void initialise(params, log, valid_params) {
        
        if (!valid_params['illumina_reads_qc_tools'].contains(params.illumina_reads_qc_tool)) {
            log.error "Invalid option: '${params.illumina_reads_qc_tool}'. Valid options for '--illumina_reads_qc_tool': ${valid_params['illumina_reads_qc_tool'].join(', ')}."
            System.exit(1)
        }
        if (!valid_params['illumina_variant_callers'].contains(params.variant_caller)) {
            log.error "Invalid option: '${params.variant_caller} for illumina data'. Valid options for '--variant_caller': ${valid_params['illumina_variant_callers'].join(', ')}."
            System.exit(1)
        }
        if (!valid_params['illumina_reads_mapping_tools'].contains(params.mapping_tool)) {
            log.error "Invalid option: '${params.mapping_tool}'. Valid options for illumina data is '--mapping_tool': ${valid_params['illumina_reads_mapping_tools'].join(', ')}."
            System.exit(1)
        }
    }

}
