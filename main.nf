nextflow.enable.dsl=2

// At the moment works only for GRCh38 data

// Print help message when --help is used
params.help = false
if (params.help) {
    println """\
        GREEN-VARAN annotation pipeline - PARAMETERS    
        ============================================
        --smallvars in.vcf.gz   :   Input small variants VCF file(s), compressed and indexed 
        --sv in.vcf.gz          :   Input structural variants VCF file(s), compressed and indexed
                                    All input files MUST be sorted, compressed and indexed
                                    You can input multiple files from a folder using quotes like
                                    --input 'mypath/*.vcf.gz'
        --sv_config             :   JSON file containing annotations config for SV
        --snpEff_data           :   Specify the snpEff data folder
        --anno_toml             :   The annotation config file.
                                    This file is a toml file as specified for vcfanno.
        --anno_resourcedir      :   You can use this to specify a resource folder for small variants annotations
                                    In this case all path given in the toml file are relative to this folder
        --lua                   :   Optional lua script file for vcfanno
        --out                   :   Output folder for annotated files

        See https://github.com/brentp/vcfanno for guide on how to prepare toml files and lua scripts
        """
        .stripIndent()

    exit 1
}

// Checks at least one input is specified
if (!params.smallvars && !params.sv) {
    exit 1, "No input file specified. Please specify a VCF file using --smallvars and/or --sv"
}

log.info """\
    ==============================================
     Variant annotation  -  N F   P I P E L I N E    
    ==============================================
    small variants      : ${params.smallvars}
    structural variants : ${params.sv}
    output              : ${params.out}
    toml file           : ${params.anno_toml}
    lua file            : ${params.lua}
    anno resource dir   : ${ params.anno_resourcedir ? ${params.anno_resourcedir} : "none" }
    sv config           : ${params.sv_config}
    snpEff data folder  : ${params.snpEff_data}
    ==============================================
    """
    .stripIndent()

// Check input files exist
checkPathParamList = [
    params.smallvars, params.sv, params.anno_toml, params.sv_config
]
for (param in checkPathParamList) { if (param) { file(param, checkIfExists: true) } }

if (params.lua) {
    file(params.lua, checkIfExists: true)
}

//Make output dir and set prefix
outputdir = file(params.out)
outputdir.mkdirs()

workflow {
    // SMALLVARS
    if (params.smallvars) {
        input_smallvars = Channel
                .fromPath(params.smallvars)
                .map { tuple(file("$it"), file("${it}.{csi,tbi}"))}
        toml_file = file(params.anno_toml)
        lua_file = file(params.lua)
        // ANNOTATE SNPEFF
        snpEff(input_smallvars, params.snpEff_data)

        // ANNOTATE VCFANNO
        vcfanno(snpEff.out.vcf, toml_file, lua_file, snpEff.out.prefix)
    }

    // SVs
    if (params.sv) { 
        input_sv = Channel
                .fromPath(params.sv)
                .map { tuple(file("$it"), file("${it}.{csi,tbi}"))}
        sv_anno(input_sv, file(params.sv_config))
    }
}

process sv_anno {
    publishDir "$outputdir", mode: 'move' 

    input:
        tuple file(vcf), file(vcf_index)
        file(sv_config)

    output:
        tuple file("${file_prefix}.annotated.vcf.gz"), file("${file_prefix}.annotated.vcf.gz.csi")

    script:
    file_prefix = ("$vcf" - ".vcf.gz")
    """
    SV_annotation.py -i $vcf -o ${file_prefix}.annotated.vcf -b ${params.build} -s $sv_config
    
    bgzip ${file_prefix}.annotated.vcf
    tabix -p vcf --csi ${file_prefix}.annotated.vcf.gz
    """
}


process snpEff {
    input:
        tuple file(vcf), file(vcf_index)
        val(data_dir)

    output:
        tuple file('snpeff.vcf.gz'), file('snpeff.vcf.gz.csi'), emit: vcf
        val(file_prefix), emit: prefix

    script:
    file_prefix = ("$vcf" - ".vcf.gz")
    """
    java -jar $projectDir/bin/snpEff.jar ann -noStats -nodownload -dataDir $data_dir GRCh38.99 $vcf \
    | bgzip -c > snpeff.vcf.gz
    
    tabix -p vcf --csi snpeff.vcf.gz
    """
}


process vcfanno {
    publishDir "$outputdir", mode: 'move' 
    
    input:
        tuple file(vcf), file(vcf_index)
        file(toml_file)
        file(lua_file)
        val(prefix)

    output:
        tuple file("${prefix}.annotated.vcf.gz"), file("${prefix}.annotated.vcf.gz.csi")

    script:
    if (!params.anno_resourcedir) {
        basedir_option = ""
    } else {
        basedir_option = "-base-path ${params.anno_resourcedir}"
    }

    """
    if [ -f $lua_file ]
    then
        lua_option="-lua $lua_file"
    else
        lua_option=""
    fi

    GOGC=2000 IRELATE_MAX_CHUNK=10000 IRELATE_MAX_GAP=1000 \
    vcfanno -p ${params.ncpus} $basedir_option \$lua_option $toml_file $vcf \
    | bgzip -c > ${prefix}.annotated.vcf.gz
    
    tabix -p vcf --csi ${prefix}.annotated.vcf.gz
    """

}
