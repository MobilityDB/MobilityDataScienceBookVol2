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




