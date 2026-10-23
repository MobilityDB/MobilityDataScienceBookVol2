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


import static functions.GeneratedFunctions.*;


public class BerlinmodInstantRecord extends InstantRecord {
			
	private int tripId;
	private OffsetDateTime t;
	
	private int vehicleId;
	private int seqNo;
	private String geom; // HexWKB expression
	

	
	
	public static BerlinmodInstantRecord builder(int aTripId, int aVehId, OffsetDateTime aT, int aSeq, String aGeom)
    {
		BerlinmodInstantRecord auxi = new BerlinmodInstantRecord();
		
		auxi.tripId= aTripId;
		auxi.vehicleId= aVehId;
		auxi.t = aT;
		auxi.seqNo= aSeq;
		auxi.geom= aGeom;
			
		return auxi;
	}

	
	public static BerlinmodInstantRecord builder(String aLine[], List<Integer> colPositions)
    {
		BerlinmodInstantRecord auxi = new BerlinmodInstantRecord();
		
		// Order: tripid vehid seqno geom t
		try {
			auxi.tripId= Integer.valueOf(aLine[colPositions.get(0)]);
			auxi.vehicleId= Integer.valueOf(aLine[colPositions.get(1)]);
			auxi.seqNo= Integer.valueOf(aLine[colPositions.get(2)]);
			auxi.geom = aLine[colPositions.get(3)];
			auxi.t= pg_timestamptz_in(aLine[colPositions.get(4)], -1);
			
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
		return String.format("%s %s %s %s %s", tripId, vehicleId, t, seqNo, geom);
	}
	

	public void setT( OffsetDateTime aT) {
		t= aT;
	}
	
	public   OffsetDateTime getT() {
		return t;
	}

	
	public void setVehicleId(int aVehicleId) {
		vehicleId= aVehicleId;
	}
	
	public int getVehicleId() {
		return vehicleId;
	}
	
	public void setSeq(int aSeqNo) {
		seqNo= aSeqNo;
	}
	public int getSeq() {
		return seqNo;
	}
	
	public void setGeom(String aGeom){
		geom= aGeom;
	}
	
	public String getGeom() {
		return geom;
	}
	

	public String getTimeStr() {
		return pg_timestamptz_out(t);
	}


	public long getMillisec() {
		return t.toInstant().toEpochMilli();
	}

	
	public void setTripId(int anID) {
		tripId= anID;
	}
	


	public String asCSVLine(char colSeparator) {
		return String.format("%s%c%s%c%s%c%s%c%s\n", 
				tripId, colSeparator, 
				vehicleId, colSeparator,
				getTimeStr(), colSeparator, 
				seqNo, colSeparator, 
				geom);
		
		
	}


	public String asCSVHeader(char colSeparator) {
		return String.format("tripid%cvehid%cseqno%cgeom%ct\n",
				colSeparator,colSeparator,colSeparator,colSeparator);
		
	}


	@Override
	public int getId() {
		return tripId;
	}
		
}




