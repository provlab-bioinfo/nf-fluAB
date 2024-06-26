<!-- # ![nf-core/influenza](docs/images/nf-influenza_logo_light.png#gh-light-mode-only) ![nf-core/influenza](docs/images/nf-influenza_logo_dark.png#gh-dark-mode-only) -->

<!--
[![AWS CI](https://img.shields.io/badge/CI%20tests-full%20size-FF9900?labelColor=000000&logo=Amazon%20AWS)](https://nf-co.re/influenza/results)[![Cite with Zenodo](http://img.shields.io/badge/DOI-10.5281/zenodo.XXXXXXX-1073c8?labelColor=000000)](https://doi.org/10.5281/zenodo.XXXXXXX)

[![Nextflow](https://img.shields.io/badge/nextflow%20DSL2-%E2%89%A521.10.3-23aa62.svg)](https://www.nextflow.io/)
[![run with conda](http://img.shields.io/badge/run%20with-conda-3EB049?labelColor=000000&logo=anaconda)](https://docs.conda.io/en/latest/)
[![run with docker](https://img.shields.io/badge/run%20with-docker-0db7ed?labelColor=000000&logo=docker)](https://www.docker.com/)
[![run with singularity](https://img.shields.io/badge/run%20with-singularity-1d355c.svg?labelColor=000000)](https://sylabs.io/docs/)
[![Launch on Nextflow Tower](https://img.shields.io/badge/Launch%20%F0%9F%9A%80-Nextflow%20Tower-%234256e7)](https://tower.nf/launch?pipeline=https://github.com/nf-core/influenza)

[![Get help on Slack](http://img.shields.io/badge/slack-nf--core%20%23influenza-4A154B?labelColor=000000&logo=slack)](https://nfcore.slack.com/channels/influenza)[![Follow on Twitter](http://img.shields.io/badge/twitter-%40nf__core-1DA1F2?labelColor=000000&logo=twitter)](https://twitter.com/nf_core)[![Watch on YouTube](http://img.shields.io/badge/youtube-nf--core-FF0000?labelColor=000000&logo=youtube)](https://www.youtube.com/c/nf-core) -->

## Introduction

<!-- TODO nf-core: Write a 1-2 sentence summary of what data the pipeline is for and what it does -->

**nf-core/influenza** is an influenza NGS sequence data analysis pipeline.

The pipeline is built using [Nextflow](https://www.nextflow.io), a workflow tool to run tasks across multiple compute infrastructures in a very portable manner. It uses Docker/Singularity containers making installation trivial and results highly reproducible. 

## Pipeline summary

<!-- TODO nf-core: Fill in short bullet-pointed list of the default steps in the pipeline -->
By default, the pipeline supports both short and long reads:

- Sequence quality check and quality control
  - Short reads
    - Short Illumina reads quality checks ([FastQC](https://www.bioinformatics.babraham.ac.uk/projects/fastqc/))
    - Short read quality control ([fastp](https://github.com/OpenGene/fastp))
    - Short read statistics ([seqkit stats](https://bioinf.shenwei.me/seqkit/usage/#stats))
    
  - Long reads
    - Nanopore long read quality checks ([NanoPlot](https://github.com/wdecoster/NanoPlot))
    - Nanopore long read adapter trimming ([Porechop](https://github.com/rrwick/Porechop))
    - Nanopore long read quality and length filter ([chopper](https://github.com/wdecoster/chopper))
    - Nanopore long read statistics ([seqkit stats](https://bioinf.shenwei.me/seqkit/usage/#stats))
- Assembly
  - Short read assembly ([mash](https://github.com/marbl/Mash)|[bwa](https://github.com/lh3/bwa)|[samtools](https://github.com/samtools/samtools)|[freebayes](https://github.com/freebayes/freebayes)|[bcftools](https://github.com/samtools/bcftools)|[bioawk](https://github.com/lh3/bioawk))
  - Long read assembly 

- Classification
  - Flu typing: [Blastn](https://blast.ncbi.nlm.nih.gov/doc/blast-help/downloadblastdata.html) search against flu typing database
  - Clade assignment: [nextclade](https://github.com/nextstrain/nextclade)
- Summarize and generate the analysis report, software version control reports

## Pipeline reference databases
* flu database
* typing database
* nextclade database
  

## Quick Start

1. Install [`Nextflow`](https://www.nextflow.io/docs/latest/getstarted.html#installation) (`>=21.10.3`)

2. Install any of [`Docker`](https://docs.docker.com/engine/installation/), [`Singularity`](https://www.sylabs.io/guides/3.0/user-guide/) (you can follow [this tutorial](https://singularity-tutorial.github.io/01-installation/)), [`Podman`](https://podman.io/), [`Shifter`](https://nersc.gitlab.io/development/shifter/how-to-use/) or [`Charliecloud`](https://hpc.github.io/charliecloud/) for full pipeline reproducibility _(you can use [`Conda`](https://conda.io/miniconda.html) both to install Nextflow itself and also to manage software within pipelines. Please only use it within pipelines as a last resort; see [docs](https://nf-co.re/usage/configuration#basic-configuration-profiles))_.

3. Download the pipeline and test it on a minimal dataset with a single command:

   ```bash
   nextflow run xiaoli-dong/influenza -profile test,YOURPROFILE --outdir <OUTDIR>
   ```

   Note that some form of configuration will be needed so that Nextflow knows how to fetch the required software. This is usually done in the form of a config profile (`YOURPROFILE` in the example command above). You can chain multiple config profiles in a comma-separated string.

   > - The pipeline comes with config profiles called `docker`, `singularity`, `podman`, `shifter`, `charliecloud` and `conda` which instruct the pipeline to use the named tool for software management. For example, `-profile test,docker`.
   > - Please check [nf-core/configs](https://github.com/nf-core/configs#documentation) to see if a custom config file to run nf-core pipelines already exists for your Institute. If so, you can simply use `-profile <institute>` in your command. This will enable either `docker` or `singularity` and set the appropriate execution settings for your local compute environment.
   > - If you are using `singularity`, please use the [`nf-core download`](https://nf-co.re/tools/#downloading-pipelines-for-offline-use) command to download images first, before running the pipeline. Setting the [`NXF_SINGULARITY_CACHEDIR` or `singularity.cacheDir`](https://www.nextflow.io/docs/latest/singularity.html?#singularity-docker-hub) Nextflow options enables you to store and re-use the images from a central location for future pipeline runs.
   > - If you are using `conda`, it is highly recommended to use the [`NXF_CONDA_CACHEDIR` or `conda.cacheDir`](https://www.nextflow.io/docs/latest/conda.html) settings to store the environments in a central location for future pipeline runs.

4. Start running your own analysis!

   <!-- TODO nf-core: Update the example "typical command" below used to run the pipeline -->

   ```bash
   nextflow run xiaoli-dong/influenza --input samplesheet.csv --outdir <OUTDIR> -profile <docker/singularity/podman/shifter/charliecloud/conda/institute>
   ```
<!--
## Documentation

The nf-fluAB pipeline comes with documentation about the pipeline [usage](https://nf-co.re/influenza/usage), [parameters](https://nf-co.re/influenza/parameters) and [output](https://nf-co.re/influenza/output).
-->
## Credits

nf-fluAB was written by Xiaoli Dong. The illumina part of this pipeline was mainly based on Dr. Matthew Croxen's [flu pipeline]().

Extensive support was provided from others on the scientific or technical input required for the pipeline:
- Dr. Matthew Croxen
- Dr. Tarah Lynch
- Kanti Pabbaraju
- Anita Wong
- Linda Lee
  
<!-- TODO nf-core: If applicable, make list of people who have also contributed -->
<!-- 
## Contributions and Support

If you would like to contribute to this pipeline, please see the [contributing guidelines](.github/CONTRIBUTING.md).

For further information or help, don't hesitate to get in touch on the [Slack `#influenza` channel](https://nfcore.slack.com/channels/influenza) (you can join with [this invite](https://nf-co.re/join/slack)).
-->
<!--
## Citations
-->
<!-- TODO nf-core: Add citation for pipeline after first release. Uncomment lines below and update Zenodo doi and badge at the top of this file. -->
<!-- If you use  nf-core/influenza for your analysis, please cite it using the following doi: [10.5281/zenodo.XXXXXX](https://doi.org/10.5281/zenodo.XXXXXX) -->

<!-- TODO nf-core: Add bibliography of tools and data used in your pipeline -->
<!--
An extensive list of references for the tools used by the pipeline can be found in the [`CITATIONS.md`](CITATIONS.md) file.

You can cite the `nf-core` publication as follows:
-->
<!--
> **The nf-core framework for community-curated bioinformatics pipelines.**
>
> Philip Ewels, Alexander Peltzer, Sven Fillinger, Harshil Patel, Johannes Alneberg, Andreas Wilm, Maxime Ulysse Garcia, Paolo Di Tommaso & Sven Nahnsen.
>
> _Nat Biotechnol._ 2020 Feb 13. doi: [10.1038/s41587-020-0439-x](https://dx.doi.org/10.1038/s41587-020-0439-x).

-->
