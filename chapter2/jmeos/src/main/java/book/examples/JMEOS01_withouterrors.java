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

package book.examples;

import types.basic.tpoint.tgeom.TGeomPointInst;    
import types.temporal.TInterpolation;
import functions.GeneratedFunctions;
import jnr.ffi.Memory;
import jnr.ffi.Pointer;
import jnr.ffi.Runtime;
import static functions.GeneratedFunctions.tsequence_make;
import java.util.ArrayList;
import java.util.List;

public class JMEOS01_withouterrors {
	
	

    public static void main(String[] args) throws Exception {
     	
      	 GeneratedFunctions.meos_initialize();
   	
    	ArrayList<String> wktData= new ArrayList<>(List.of(
    				"Point(0 0)@2018-01-01 12:00:00",
    	    		"Point(6 0)@2018-01-01 12:00:06",
    	    		"Point(6 6)@2018-01-01 12:00:11",
    	    		"Point(9 9)@2018-01-01 12:00:14"
    			));
    	
 
    	// Build the trips
    	Runtime runtime = Runtime.getSystemRuntime();
  	  
    	// Allocate memory for array of pointers for trip instants
    	Pointer tripInstantsArray = Memory.allocate(runtime, wktData.size() * Long.BYTES);

    	int qty= 0;
    	for (String aStr : wktData) {
    		// Option 2
    		Pointer aPointer = GeneratedFunctions.tgeompoint_in(aStr);
    		
    		// Alternatively, Option 1
    		// Pointer aPointer = new TGeomPointInst(aStr).getInner();
    		
    	  	tripInstantsArray.putPointer(qty++ * Long.BYTES, aPointer);
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