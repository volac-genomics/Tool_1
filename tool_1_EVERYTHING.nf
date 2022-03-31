#!/usr/bin/env nextflow

inputContigs = Channel.fromPath("$baseDir/LIBRARY/*.fa", type: 'file')

ch_flatContigs = inputContigs.map { [ it.getBaseName(), it ] }



//////////////////////////////////
//        HELP MESSAGE          //
//////////////////////////////////

def helpMessage() {
    log.info """
        Execute mass screening using ABRicate tool. 
        Downloads current database and provides summary file.
        Queries all *.fa files in LIBRARY/
        Usage: nextflow run tool_1_EVERYTHING.nf [options]

	Options:
	--abricateDB 'xxx'	
            argannot, card, ecoh, ecoli_vf, ncbi, plasmidfinder, resfinder and vfdb [default: card]
	--identity 'yy' 	
            Minimum DNA %identity [default: 80].
	--coverage 'zz'		
            Minimum DNA %coverage [default: 50].

	Example:
	nextflow run tool_1_EVERYTHING.nf --abricateDB 'resfinder' --identity '90' --coverage '75'

        ALTERNATIVE: use tool_1.nf to screen selection of strains
        """
}

// Show help message
if (params.help) {
    helpMessage()
    exit 0
}


// Abricate parameters
// List of abricate databases
abricate_database = params.abricateDB

// Abricate --minid value
abricate_ID = "${params.identity}"

// Abricate --mincov value
abricate_Cov = "${params.coverage}"


//////////////////////////////////
//   SETUP OUTPUT DIRECTORIES   //
//////////////////////////////////

// Generate formatted dateTime
Date today = new Date()
    YearMonthDay = today.format( "yyyy-MM-dd_HH:mm" )
    OutputDir = "${YearMonthDay}"

// Define output path
RunID_output_path = "$baseDir/output_tool1/${abricate_database}-i${abricate_ID}-c${abricate_Cov}__${OutputDir}"

// Make output directory
File outputDirectory = new File("${RunID_output_path}")
outputDirectory.mkdirs()


//////////////////////////////////
//    SETUP DATABASE INPUT      //
//////////////////////////////////

Channel.from( abricate_database ).set{ ch_abricateDB }


//////////////////////////////////
//     WRITE CONFIG TO FILE     //
//////////////////////////////////

// Write run parameters to file, line by line
configFileName = "${RunID_output_path}/run_parameters.txt"

File parametersFile = new File("${configFileName}")
parametersFile.withWriter{ out ->
  params.each {out.println it }
}

Channel.fromPath( "${configFileName}" ).set{ ch_configFile }


process massScreeningDatabaseDownload {

        publishDir "${RunID_output_path}/", mode: 'copy'

	input:
        set database, file(configFile) from ch_abricateDB.combine( ch_configFile )
	
	output:
	set database, file("${database}") into ch_abricateDBDownload

	script:
	"""
        abricate --version >> run_parameters.txt  
        abricate-get_db --db ${database} --dbdir .
	abricate --list --datadir . | grep "${database}" >> ${configFile}
        """
}


process massScreening {

        tag "$dataset_id"

        cpus 4

        publishDir "${RunID_output_path}/isolate", mode: 'copy'

        input:
        set dataset_id, file(query), database_name, file(database) from ch_flatContigs.combine( ch_abricateDBDownload )

        output:
        file "${dataset_id}-${abricate_database}-i${abricate_ID}-c${abricate_Cov}.tab" into ch_abricateOutput

        script:
        """
       	abricate --db '${abricate_database}' --datadir . --minid '${abricate_ID}' --mincov '${abricate_Cov}' $query > ${dataset_id}-${abricate_database}-i${abricate_ID}-c${abricate_Cov}.tab
        """
}


process massScreeningSummary {

        cpus 4

        publishDir "${RunID_output_path}/summary", mode: 'copy'

        input:
        file('*') from ch_abricateOutput.toList()

        output:
        file "summary_${abricate_database}-i${abricate_ID}-c${abricate_Cov}.tab" into ch_ABRsummary

        script:
        """
        abricate --summary * > summary_${abricate_database}-i${abricate_ID}-c${abricate_Cov}.tab
        """
}

//// THE END ////

