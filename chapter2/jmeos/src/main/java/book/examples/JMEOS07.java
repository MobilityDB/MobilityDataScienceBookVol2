package book.examples;

     
import functions.MeosErrorHandler;    
import functions.GeneratedFunctions;
import jnr.ffi.Memory;
import jnr.ffi.Pointer;
import jnr.ffi.Runtime;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.List;
import book.examples.utils.BerlinmodTripRecord;
import book.examples.utils.CSVRecords;
import static functions.GeneratedFunctions.*;


public class JMEOS07 {
 
    public static void main(String[] args) throws Exception {
    	
    	 GeneratedFunctions.meos_initialize();
         GeneratedFunctions.meos_initialize_timezone("UTC");
         GeneratedFunctions.meos_initialize_error_handler(new MeosErrorHandler());
    	
         CSVRecords.setSkipHeaderLines(1);  // skip header
    	
         // Read the CSV file into a collection.
         // First parameter absolute path of the CSV file
         // Second parameter indicate the positional columns to use when 
         // populating a BerlinmodTripRecord.
         // Last parameter the name of the fn to build a BerlinmodTripRecord. 
         ArrayList<BerlinmodTripRecord> dataTrips = 
        	CSVRecords.readRecords("/data/berlinmod_trips.csv",
        	List.of(0,1,2,3,4),
        	BerlinmodTripRecord::builder
  		 );
      	
        
         // Variables for keeping current aggregate state
         Pointer extent = null;  // STBox
         Pointer state = null;   // TCount
         
         // Use this starting time and an hour granularity 
         OffsetDateTime origin = pg_timestamptz_in("2020-06-01", -1);
         Pointer interval = pg_interval_in("1 hour", -1);
         
     
         
       	 for (BerlinmodTripRecord tripRec : dataTrips) {
       		
       		 // Add to spatial-temporal extent
             extent = tspatial_extent_transfn(extent, tripRec.getTrip());
             
             // Get the time of the trip
             Pointer tempTime = temporal_time(tripRec.getTrip());

             // Apply time precision (group by hour)
             Pointer ps = tstzspanset_tprecision(tempTime, interval, origin);

             // Aggregate the time if this tip to temporal count
             state = tstzspanset_tcount_transfn(state, ps);
             
       	 }
       	 
       	System.out.printf("%n%d trip records read%n%n", dataTrips.size());

       
        // Print extent
        System.out.println("Extent");
        System.out.println("------");
        System.out.println();

        if (extent != null) {
            String extentStr = stbox_out(extent, 6);
            System.out.println(extentStr);
            System.out.println();
        }
	
       	
        // Print temporal count
        System.out.println("Temporal count");
        System.out.println("--------------");
        System.out.println();

        if (state != null) {
            // Finalize aggregation
            Pointer tcount = temporal_tagg_finalfn(state);

            if (tcount != null) {
                // Extract sequences
                Runtime runtime = Runtime.getSystemRuntime();
                Pointer countPtr = Memory.allocate(runtime, Integer.BYTES);

                Pointer tcountSeqs = temporal_sequences(tcount, countPtr);
                int seqCount = countPtr.getInt(0);

                // Print each sequence
                for (int i = 0; i < seqCount; i++) {
                    Pointer seqPtr = tcountSeqs.getPointer(i * Long.BYTES);
                    String seqStr = tint_out(seqPtr);
                    System.out.println(seqStr);
                }
            }
        }

     
    
  
       GeneratedFunctions.meos_finalize();
    }
    
}
