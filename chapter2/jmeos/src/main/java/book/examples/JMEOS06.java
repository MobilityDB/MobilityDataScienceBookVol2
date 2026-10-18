package book.examples;

     
import functions.MeosErrorHandler;   
import functions.GeneratedFunctions;
import java.util.ArrayList;
import java.util.List;
import book.examples.utils.BerlinmodSimplifiedTripRecord;
import book.examples.utils.CSVRecords;
import static functions.GeneratedFunctions.*;


public class JMEOS06 {
 	
    public static void main(String[] args) throws Exception {
    	
    	 GeneratedFunctions.meos_initialize();
         GeneratedFunctions.meos_initialize_timezone("UTC");
         GeneratedFunctions.meos_initialize_error_handler(new MeosErrorHandler());
     	
    	
         CSVRecords.setSkipHeaderLines(1);  // skip header
    	
          // Read the CSV file into a collection.
         // First parameter absolute path of the CSV file
         // Second parameter indicate the positional columns to use when 
         // populating a BerlinmodSimplifiedTripRecord.
         // Last parameter the name of the fn to build a BerlinmodSimplifiedTripRecord. 
         ArrayList<BerlinmodSimplifiedTripRecord> dataTrips = 
        	CSVRecords.readRecords("/data/berlinmod_trips.csv",
        	List.of(0,1,2,3,4),
        	BerlinmodSimplifiedTripRecord::builder
  		 );
      	
        
 
         // Simplify the trips
         System.out.println("Simplifying trips...");
         System.out.println();

         int totalOriginal = 0;
         int totalDP = 0;
         int totalSED = 0;
         
         // Print header
		System.out.printf("%7s|%10s|%3s|%14s|%14s|%14s|%9s|%9s|%10s|%10s%n", 
				"vehicle", "date", "seq", 
				"inst. trip qty", "inst. dp qty",  "inst. sed qty",
				"dp-delta", "sed-delta", "dp-%", "sed-%");
        System.out.println("---------------------------------------------------------------");
   
        // Table
         for (BerlinmodSimplifiedTripRecord trip : dataTrips) {

             // Get counts
             int originalCount = temporal_num_instants(trip.getTrip());
             int dpCount = temporal_num_instants(trip.getSimplifiedTripDP());
             int sedCount = temporal_num_instants(trip.getSimplifiedTripSed());

             // Print results
             System.out.printf("%7d|%10s|%3d|%14d|%14d|%14d|%9d|%9d|%10.6f|%10.6f%n", 
            		 trip.getVehicleId(), trip.getDateNoTimeAsString(), 
                     trip.getSeqNo(), 
                     originalCount, dpCount, sedCount,
                     originalCount-dpCount, originalCount-sedCount,
                     dpCount*100.0/originalCount, sedCount*100.0/originalCount
                     );
             
             // For the summary
             totalOriginal += temporal_num_instants(trip.getTrip());
             totalDP += temporal_num_instants(trip.getSimplifiedTripDP());
             totalSED += temporal_num_instants(trip.getSimplifiedTripSed());
         }

         // Print summary statistics
         System.out.println();
         System.out.println("Summary:");

         double dpReduction = 100.0 * (totalOriginal - totalDP) / totalOriginal;
         double sedReduction = 100.0 * (totalOriginal - totalSED) / totalOriginal;

         System.out.printf("Total original instants: %d%n", totalOriginal);
         System.out.printf("Total DP instants: %d (%.1f%% reduction)%n", totalDP, dpReduction);
         System.out.printf("Total SED instants: %d (%.1f%% reduction)%n", totalSED, sedReduction);
    
        GeneratedFunctions.meos_finalize();
    }

}
