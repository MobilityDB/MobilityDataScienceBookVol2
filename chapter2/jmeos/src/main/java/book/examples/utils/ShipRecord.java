package book.examples.utils;

import static functions.GeneratedFunctions.geogpoint_make2d;    
import static functions.GeneratedFunctions.tfloatinst_make;
import static functions.GeneratedFunctions.tpointinst_make;
import static functions.GeneratedFunctions.tsequence_make;
import static functions.GeneratedFunctions.temporal_simplify_dp;
import static functions.GeneratedFunctions.tspatial_out;
import static functions.GeneratedFunctions.tfloat_out;
import java.util.ArrayList;
import jnr.ffi.Memory;
import jnr.ffi.Pointer;
import jnr.ffi.Runtime;
import types.temporal.TInterpolation;

public class ShipRecord {
	
	 /* Epsilon distance used for simplification (meters) */
    static final double DELTA_DISTANCE = 0.001;
	
    private long MMSI;   /* Identifier of the trip */
    private Pointer trip;  /* Trip constructed from the input instants */
    private Pointer SOG;   /* SOG constructed from the input instants */
    
    private Pointer simplifiedTrip;
    
    
    public static ShipRecord builder(Long ID, ArrayList<AISRecord> aisRecs ) {
    	System.out.println("Number of records after the filter was applied: " +  aisRecs.size());
    	
		ShipRecord auxi = new ShipRecord();
	
		Runtime runtime = Runtime.getSystemRuntime();

		Pointer tripInstantsArray = Memory.allocate(runtime, aisRecs.size() * Long.BYTES);
     	Pointer sogInstantsArray = Memory.allocate(runtime, aisRecs.size() * Long.BYTES);
    	 
 		// fill the array with the information
    	int i= 0;
    	for (AISRecord aisRecord : aisRecs) {
			
			Pointer geo = geogpoint_make2d(4326, aisRecord.getLongitude(), aisRecord.getLatitude());
			Pointer aTripInstant = tpointinst_make(geo, aisRecord.getT());
			tripInstantsArray.putPointer(i * Long.BYTES, aTripInstant);
			
			Pointer aSogInstant = tfloatinst_make(aisRecord.getSOG(), aisRecord.getT());
			sogInstantsArray.putPointer(i * Long.BYTES, aSogInstant);
			 
	    	i++;
		}
		
    	auxi.MMSI= ID;

        // Create the trip sequence 
    	auxi.trip = tsequence_make(tripInstantsArray, aisRecs.size(),
                true, true, TInterpolation.LINEAR.getValue(), true);
    	
        // Create the sog sequence 
    	auxi.SOG = tsequence_make(sogInstantsArray, aisRecs.size(),
                true, true, TInterpolation.LINEAR.getValue(), true);
    	
        // Douglas-Peucker simplification (synchronize = true)
    	// Not only the spatial distance is being used.
    	auxi.simplifiedTrip = temporal_simplify_dp(auxi.trip, DELTA_DISTANCE, true);
    	
//   	System.out.println(auxi.getSOGAsString());
 		return auxi;
	}
    
    
    
    public Pointer getTrip(){
    	return trip;
    	
    }
    
    public String getTripAsString() {
    	return tspatial_out(trip, 15);
    }
    

	public Pointer getSimplifiedTrip(){
    	return simplifiedTrip;
    }
    
    public Pointer getSOG(){
    	return SOG;
    	
    }
    
    public String getSOGAsString() {
    	return  tfloat_out(SOG, 15);
    }
    
    public long getMMSI() {
    	return MMSI;
    }
    
    
};
