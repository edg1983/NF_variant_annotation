# Variant annotation workflow

Nextflow workflow to annotate variants from VCF file, either small vars or structural vars

## Usage

Bu default the workflow search for some configuration files in the config folder, this can be changed in the nextflow.config. Then, the minimum command is:

```
nextflow main.nf --smallvars input_smallvars.vcf.gz --sv input_SV.vcf.gz --out output_folder
```

**NB.** Input files must be .vcf.gz, compressed and indexed VCF files

## arguments

The arguments available for the pipeline are:

| argument | description |
| -------- | ----------- |
| --smallvars in.vcf.gz | Input small variants VCF file(s), compressed and indexed |
| --sv in.vcf.gz | Input structural variants VCF file(s), compressed and indexed<br>All input files MUST be sorted, compressed and indexed<br>You can input multiple files from a folder using quotes like 'mypath/*.vcf.gz' |
| --sv_config  | JSON file containing annotations config for SV |
| --snpEff_data | Specify the snpEff data folder |
| --anno_toml | The annotation config file.<br>This file is a toml file as specified for vcfanno |
| --anno_resourcedir | You can use this to specify a resource folder for small variants annotations<br>n this case all path given in the toml file are relative to this folder |
| --lua | Optional lua script file for vcfanno |
| --out | Output folder for annotated files |

See [vcfanno repository](https://github.com/brentp/vcfanno) for guide on how to prepare toml files and lua scripts

## configuration
Before you can run the pipeline on your system you need to update the following

1. toml configuration file. An example is in `config`. This contains the configuration for small variants annotation as used by [vcfanno](https://github.com/brentp/vcfanno).

2. SV_annotation.json. An example is in `config`. These configure BED files used to annotate structural variants and how to process them. A dataset with useful files is provided in a [Zenodo repository](https://zenodo.org/record/3970785)

3. If you are running annotation for SV, be sure that the path containing the annotation file configured in `SV_annotation.json` is configured as mounting path in `nextflow.config` singularity scope with `runOptions = "--bind /my/path:/my/path"` 

You can then update the nextflow configuration `nextflow.config` to point to your toml and SV json files or pass them at the command line using the corresponding argument.

## Pipeline components

- snpEff 5.0e
- vcfanno 0.3.3
- SV_annotation.py