package book.examples;

     
import functions.MeosErrorHandler;   
import functions.functions;
import jnr.ffi.Runtime;
import static functions.functions.temporal_num_instants;
import static functions.functions.tpoint_length;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import book.examples.utils.AISReadRecords;
import book.examples.utils.AISRecord;
import book.examples.utils.PGDBStore;
import book.examples.utils.ShipRecord;

public class JMEOS03 {
 
    public static void main(String[] args) throws Exception {
    	
    	 functions.meos_initialize();
         functions.meos_initialize_timezone("UTC");
         functions.meos_initialize_error_handler(new MeosErrorHandler());
         functions.meos_set_datestyle("ISO, DMY", null);  // day/month/year
     	
    	
    	AISReadRecords.setSkipHeaderLines(1);  // no header
    	
    	// Read the CSV file from resource folder.
    	// The information are in chronologically ascendant order, not sorted by MMSI.
    	// A Hashmap is built for associating each MMSI with all its AIS records.
    	// Second parameter indicate the positional columns to use when 
    	// populating AISRecords.
    	// Last parameter is a Lambda fn used to filter data. 
    	 HashMap<Long, ArrayList<AISRecord>> data = 
    			 AISReadRecords.readRecords("/data/aisdk-2026-01-20.csv",
    			 List.of(0,2,3,4,7),
    			 
    			 // lambda filter
    			 aRec -> aRec.getLatitude() >= 40.18 &&  aRec.getLatitude() <= 84.17
    			    &&
    			    aRec.getLongitude() >= -16.1 &&  aRec.getLongitude() <= 32.88
    			    &&
    			    aRec.getSOG() >= 0 && aRec.getSOG() <= 1022
    			    
    			    );
    	
     	// Once the total AIS records are read we can calculate 
    	// temporal attributes trip and SOG for each MMSI.
    	// The whole information is stored as a collection of ShipRecords
     	ArrayList<ShipRecord> shipRecords = new ArrayList<>();

     	Runtime runtime = Runtime.getSystemRuntime();
     	for (Map.Entry<Long, ArrayList<AISRecord>> AISRecsXMMSI : data.entrySet()) {
     		// Processing AIS Recs for one MMSI
     		 Long anMMSI = AISRecsXMMSI.getKey();
     		 ArrayList<AISRecord> itsAISRecords = AISRecsXMMSI.getValue();
     		 
     		 System.out.println("Processing trip and SOG for MMSI " + anMMSI);
     		 
     		 // Generate its spatiotemporal trips and temporal float SOG 
     		 ShipRecord auxi = ShipRecord.builder(AISRecsXMMSI.getKey(), itsAISRecords ) ;
       		 shipRecords.add( auxi );
     	}
        
     	
     	for (ShipRecord trip : shipRecords) {
     		 System.out.printf("  Trip %d-> Number of instants: %d, Distance travelled %f%n",
                     trip.getMMSI(), temporal_num_instants(trip.getTrip()), tpoint_length(trip.getTrip()));
     		 
          
    		 System.out.printf(" Simplified Trip by Douglas-Peucker %d-> Number of instants: %d, Distance travelled %f%n",
                     trip.getMMSI(), temporal_num_instants(trip.getSimplifiedTrip()), tpoint_length(trip.getSimplifiedTrip()));

 
     	}
     	
     	// Now store the information in a PosgreSQL MobilityDB
     	PGDBStore db = new PGDBStore();
     	
     	// The  database name should be in lowercase
     	db.createDatabase("vessels");
     	db.createShipsTable();
     	db.populateShipsTable(shipRecords);
      
        functions.meos_finalize();
    }
}