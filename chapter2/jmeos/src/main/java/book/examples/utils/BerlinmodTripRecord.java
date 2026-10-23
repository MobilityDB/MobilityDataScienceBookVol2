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

import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;
import java.util.TreeSet;

import jnr.ffi.Memory;
import jnr.ffi.Pointer;
import jnr.ffi.Runtime;
import types.temporal.TInterpolation;

import static functions.GeneratedFunctions.*;

// T is the class of the identifier of this kind of record
//public class BerlinmodTripRecord<T extends Comparable<T>> implements TripRecord<T> {
public class BerlinmodTripRecord extends TripRecord{
	private int tripId;
	private Pointer trip; // from HexWKB
	
	// more information
	private int vehicleId;
	private OffsetDateTime startDate; // it is a date with no time
	private int startDateNoTime;  // no time 
	private int seqNo;
	
	 
	private BerlinmodTripRecord() {
	}
	

	public static BerlinmodTripRecord builder(Integer Id, 
			ArrayList<BerlinmodInstantRecord> aisRecs) {

   	
		BerlinmodTripRecord auxi = new BerlinmodTripRecord();
	
		Runtime runtime = Runtime.getSystemRuntime();

		Pointer tripInstantsArray = Memory.allocate(runtime, aisRecs.size() * Long.BYTES);
    	 
 		// fill the array with the information
    	int i= 0;
    	for (BerlinmodInstantRecord aisRecord : aisRecs) {
			
			Pointer geo = tgeompoint_in(aisRecord.getGeom());
			Pointer aTripInstant = tpointinst_make(geo, aisRecord.getT());
			tripInstantsArray.putPointer(i * Long.BYTES, aTripInstant);

			i++;
		}
		
    	auxi.tripId= Id;

        // Create the trip sequence 
    	auxi.trip = tsequence_make(tripInstantsArray, aisRecs.size(),
                true, true, TInterpolation.LINEAR.getValue(), true);
    	
   	
    	System.out.println(auxi.getTripAsString());
 		return auxi;
 		
	}
	
	

	 
	  
	public static BerlinmodTripRecord builder(String[] aLine, List<Integer> colsPoistions) {
		BerlinmodTripRecord auxi = new BerlinmodTripRecord();
		
		try {
			auxi.tripId= Integer.valueOf(aLine[colsPoistions.get(0)]);
			auxi.vehicleId= Integer.valueOf(aLine[colsPoistions.get(1)]);
			auxi.startDate = pg_timestamptz_in(aLine[colsPoistions.get(2)], -1);
			auxi.startDateNoTime= pg_date_in(aLine[colsPoistions.get(2)]);
			auxi.seqNo= Integer.valueOf(aLine[colsPoistions.get(3)]);
			auxi.trip = temporal_from_hexwkb(aLine[colsPoistions.get(4)]);
			
			return auxi;
		}
		catch (Exception e) {
         System.err.println("Invalid Record ignored " +  
			String.join(", ", aLine)  + e);
			return null;
		}
		

	}
	
	
	
	@Override
	public String toString() {
		return String.format("%s %s %s %s %s", tripId, vehicleId, startDate, seqNo, getTripAsString());
	}
	
	
	public int getVehicleId() {
		return vehicleId;
	}

	public  OffsetDateTime getDate() {
		return startDate;
	}
	
	public int getDateNoTime() {
		return startDateNoTime;
	}
	
	public String getDateNoTimeAsString() {
		return pg_date_out(startDateNoTime);
	}
	
	public int  getSeqNo() {
		return seqNo;
	}



	public String getTripAsString() {
		return tspatial_out(trip, 15);	}


	public Pointer getTrip() {
		return trip;
	}




	public long getMillisec() {
		return startDate.toInstant().toEpochMilli();
	}

	
	  
	@Override
	public Set<BerlinmodInstantRecord> unnest() {
		Set<BerlinmodInstantRecord> treeSet = new TreeSet<>();
	
		int numInstants = temporal_num_instants(getTrip());
		 
        // iterate over the instants of the trip
        for (int i = 0; i < numInstants; i++) {
            try {
                // Get the i-th instant
                Pointer instPtr = temporal_instant_n(getTrip(), i + 1);

                if (instPtr == null) {
                    System.out.println("Null instant " + i + " for trip " + getId());
                    continue;
                }

              
	            // Get instant as string: "SRID=3857;POINT(x y)@timestamp"
	            String instStr = tspatial_out(instPtr, 6);
	
	            // Split by @ to separate geometry from timestamp: geom@timestamp
	            String[] split= instStr.split("@");  
	            if (split.length <= 1) {
	            	System.out.println("Invalid instant format: " + instStr);
	                continue;
	            }
            
	            // build an instant builder
	            BerlinmodInstantRecord aRec = BerlinmodInstantRecord.builder(getId(),getVehicleId(),
	            		pg_timestamptz_in(split[1], -1), getSeqNo(), split[0] );
       		
	            treeSet.add(aRec);
            } 
            catch (Exception e) {
                System.out.println("Error processing instant " + i + " of trip " + getId() + ": " + e.getMessage());
            }
        }   
        
        return treeSet;
	
	}


	@Override
	public int getId() {
		return tripId;	
	}



      

}


