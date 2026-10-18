package book.examples;

     
import functions.MeosErrorHandler; 
import functions.GeneratedFunctions;

import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.List;

import book.examples.utils.BerlinmodInstantRecord;
import book.examples.utils.BerlinmodTripRecord;
import book.examples.utils.CSVRecords;

class X { 
	public static X builder22(String[] Id, List<Integer> aisRecs)
	{return new X(); 
	} ;
	}


public class JMEOS04 {
 
    public static void main(String[] args) throws Exception {
    	
    	 GeneratedFunctions.meos_initialize();
         GeneratedFunctions.meos_initialize_timezone("UTC");
         GeneratedFunctions.meos_initialize_error_handler(new MeosErrorHandler());
     	
    	
    	CSVRecords.setSkipHeaderLines(1);  // header
    	
    	// Read the CSV file from resource folder.
    	// The information are in chronologically ascendant order, not sorted by MMSI.
    	// A Hashmap is built for associating each MMSI with all its AIS records.
    	// Second parameter indicate the positional columns to use when 
    	// populating AISRecords.
    	// Last parameter is a Lambda fn used to filter data. 
    	  ArrayList<BerlinmodTripRecord> data = 
    	CSVRecords.readRecords("/data/berlinmod_trips.csv",
		 List.of(0,1,2,3,4),
		 BerlinmodTripRecord::builder
		    );
    	  

    	  ArrayList<X> data2 = 
    		    	CSVRecords.readRecords("/data/berlinmod_trips.csv",
    				 List.of(0,1,2,3,4),
    				 X::builder22
    				    );
    	  
    	  
    	// Now disassemble the trip and store the information in other CSV file
    	// sorted by chronological ascending order 
    	CSVRecords.writeInstantRecords("/data/berlinmod_disassembled_trips.csv", data,
    			BerlinmodTripRecord::unnest);
    	
    	 
      
        GeneratedFunctions.meos_finalize();
    }
}
