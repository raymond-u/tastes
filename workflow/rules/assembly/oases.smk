def get_insert_size(_, input):
    with open(input.config, "r") as config:
        return config.read().split()[4][8:]

def get_number_of_threads(_, threads):
    return threads - 1

rule oases_hash:
    input:
        expand("{{path}}/pooled/ORNA/pooled_{pair}.fq", pair=[1, 2])
    output:
        expand("{{path}}/pooled/oases/k{kmer}/Sequences", kmer=range(config["oases"]["kmer_min"], config["oases"]["kmer_max"] + 1, config["oases"]["kmer_step"]))
    log:
        "{path}/pooled/oases/logs/velveth.log"
    params:
        kmer_min=config["oases"]["kmer_min"],
        kmer_max=config["oases"]["kmer_max"],
        kmer_step=config["oases"]["kmer_step"],
        num_threads=get_number_of_threads
    threads:
        8
    shell:
        # set number of threads for OPENMP
        "export OMP_NUM_THREADS={params.num_threads} && export OMP_THREAD_LIMIT={threads}" \
        " && velveth {wildcards.path:q}/pooled/oases/k {params.kmer_min},{params.kmer_max},{params.kmer_step} -shortPaired" \
        " -fastq -separate {input:q} 2> {log:q} && for i in {{{params.kmer_min}..{params.kmer_max}..{params.kmer_step}}};" \
        " do mv -f {wildcards.path:q}/pooled/oases/k_\"$i\" {wildcards.path:q}/pooled/oases/k\"$i\"; done"

rule oases_graph:
    input:
        sequences="{path}/pooled/oases/k{kmer}/Sequences",
        config="{path}/pooled/soapdenovotrans/pooled.config"
    output:
        "{path}/pooled/oases/k{kmer}/contigs.fa"
    log:
        "{path}/pooled/oases/logs/velvetg_k{kmer}.log"
    params:
        insert_size=get_insert_size,
        num_threads=get_number_of_threads
    threads:
        8
    shell:
        # set number of threads for OPENMP
        "export OMP_NUM_THREADS={params.num_threads} && export OMP_THREAD_LIMIT={threads}" \
        " && velvetg {wildcards.path:q}/pooled/oases/k{wildcards.kmer} -ins_length {params.insert_size} -read_trkg yes 2> {log:q}"

rule oases:
    input:
        contigs="{path}/pooled/oases/k{kmer}/contigs.fa",
        config="{path}/pooled/soapdenovotrans/pooled.config"
    output:
        "{path}/pooled/oases/assembly_k{kmer}.fa"
    log:
        "{path}/pooled/oases/logs/assembly_k{kmer}.log"
    params:
        insert_size=get_insert_size
    shell:
        # oases does not support multi-threading
        "oases {wildcards.path:q}/pooled/oases/k{wildcards.kmer} -ins_length {params.insert_size} -scaffolding yes" \
        " -min_trans_lgth 200 2> {log:q} && mv -f {wildcards.path:q}/pooled/oases/k{wildcards.kmer}/transcripts.fa {output:q}"
