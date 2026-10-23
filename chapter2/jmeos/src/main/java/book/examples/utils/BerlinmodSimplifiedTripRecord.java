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
import java.util.List;
import java.util.Set;
import jnr.ffi.Pointer;

import static functions.GeneratedFunctions.*;

// T is the class of the identifier of this kind of record
//public class BerlinmodTripRecord<T extends Comparable<T>> implements TripRecord<T> {
public class BerlinmodSimplifiedTripRecord extends TripRecord{
	static final double DELTA_DISTANCE = 20;
	
	private int tripId;
	private Pointer trip; // from HexWKB
	
	// more information
	private int vehicleId;
	private OffsetDateTime startDate; // it is a date with no time
	private int startDateNoTime;  // no time 
	private int seqNo;
	
    private Pointer simplifiedTripDP;
    private Pointer simplifiedTripSed;
 
	private BerlinmodSimplifiedTripRecord() {
	}
	

	  
	public static BerlinmodSimplifiedTripRecord builder(String[] aLine, List<Integer> colsPoistions) {
		BerlinmodSimplifiedTripRecord auxi = new BerlinmodSimplifiedTripRecord();
		
		try {
			auxi.tripId= Integer.valueOf(aLine[colsPoistions.get(0)]);
			auxi.vehicleId= Integer.valueOf(aLine[colsPoistions.get(1)]);
			auxi.startDate = pg_timestamptz_in(aLine[colsPoistions.get(2)], -1);
			auxi.startDateNoTime= pg_date_in(aLine[colsPoistions.get(2)]);
			auxi.seqNo= Integer.valueOf(aLine[colsPoistions.get(3)]);
			auxi.trip = temporal_from_hexwkb(aLine[colsPoistions.get(4)]);
			
			// Douglas-Pecker algorithm
			auxi.simplifiedTripDP = temporal_simplify_dp(auxi.trip, DELTA_DISTANCE, false);
            // Synchronized Euclidean Distance simplification (synchronize = true)
            auxi.simplifiedTripSed = temporal_simplify_dp(auxi.trip, DELTA_DISTANCE, true);
			
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
		return tspatial_out(trip, 15);	
	}


	public Pointer getTrip() {
		return trip;
	}



	@Override
	public int getId() {
		return tripId;	
	}
   
	public Pointer getSimplifiedTripDP(){
    	return simplifiedTripDP;
    }
	
	public Pointer getSimplifiedTripSed(){
    	return simplifiedTripSed;
    }



	@Override
	Set<? extends InstantRecord> unnest() {
		// TODO Auto-generated method stub
		throw new RuntimeException("No implemented the unnest serialization");
	}



	@Override
	public long getMillisec() {
		return startDate.toEpochSecond();
	}

}


