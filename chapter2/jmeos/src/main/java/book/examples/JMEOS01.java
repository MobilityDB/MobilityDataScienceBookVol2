package book.examples;

import types.basic.tpoint.tgeom.TGeomPointInst;     
import types.temporal.TInterpolation;
import functions.MeosErrorHandler;
import functions.MeosException;
import functions.GeneratedFunctions;
import jnr.ffi.Memory;
import jnr.ffi.Pointer;
import jnr.ffi.Runtime;
import static functions.GeneratedFunctions.tsequence_make;
import java.util.ArrayList;
import java.util.List;

public class JMEOS01 {
	
	

    public static void main(String[] args) throws Exception {
     	
      	 GeneratedFunctions.meos_initialize();
         GeneratedFunctions.meos_initialize_error_handler(new MeosErrorHandler());
    	
    	ArrayList<String> wktData= new ArrayList<>(List.of(
				"Point(0 0)@2018-01-01 12:00:00",
				"Point(6, 0)@2018-01-01 12:00:06",
				"Point(6 6)@2018-01-01 12:00:11",
				"Point(9 9@2018-01-01 12:00:14"
												));
    	
 
    	// Build the trips
    	Runtime runtime = Runtime.getSystemRuntime();
  	  
    	// Allocate memory for array of pointers for trip instants
    	Pointer tripInstantsArray = Memory.allocate(runtime, wktData.size() * Long.BYTES);

    	int qty= 0;
    	for (String aStr : wktData) {
    		// Option 2
    		try {
    			Pointer aPointer = GeneratedFunctions.tgeompoint_in(aStr);
        	  	tripInstantsArray.putPointer(qty++ * Long.BYTES, aPointer);
    		}
    		catch(MeosException e)
    		{
    			System.out.println(e + ": " + aStr);
    		}
   		
    	}


        // Create the trip sequence 
    	Pointer trip = tsequence_make(tripInstantsArray, qty,
                true, true, TInterpolation.LINEAR.getValue(), true);
          
  
    	// Extract some information from the trip
    	TGeomPointInst tripInst = new TGeomPointInst(trip);
        System.out.printf("Trip -> Number of instants: %d, " +
        			"Distance travelled %f%n, Bounds: %s\n",
        			tripInst.num_instants(), tripInst.length(), tripInst.bounding_box_point().toString(10));
        
        // Alternatively, 
        // tripInst.num_instants()  equivalent to temporal_num_instants(trip)
        // tripInst.length() equivalent to tpoint_length(trip, true)
     
        GeneratedFunctions.meos_finalize();
    }
}