/*****************************************************************************
 *
 * This MobilityDB code is provided under The PostgreSQL License.
 * Copyright (c) 2025-2026, Université libre de Bruxelles and MobilityDB
 * contributors
 *
 * Permission to use, copy, modify, and distribute this software and its
 * documentation for any purpose, without fee, and without a written
 * agreement is hereby granted, provided that the above copyright notice and
 * this paragraph and the following two paragraphs appear in all copies.
 *
 * IN NO EVENT SHALL UNIVERSITE LIBRE DE BRUXELLES BE LIABLE TO ANY PARTY FOR
 * DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES, INCLUDING
 * LOST PROFITS, ARISING OUT OF THE USE OF THIS SOFTWARE AND ITS DOCUMENTATION,
 * EVEN IF UNIVERSITE LIBRE DE BRUXELLES HAS BEEN ADVISED OF THE POSSIBILITY
 * OF SUCH DAMAGE.
 *
 * UNIVERSITE LIBRE DE BRUXELLES SPECIFICALLY DISCLAIMS ANY WARRANTIES,
 * INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
 * AND FITNESS FOR A PARTICULAR PURPOSE. THE SOFTWARE PROVIDED HEREUNDER IS ON
 * AN "AS IS" BASIS, AND UNIVERSITE LIBRE DE BRUXELLES HAS NO OBLIGATIONS TO
 * PROVIDE MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR MODIFICATIONS.
 *
 *****************************************************************************/

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
