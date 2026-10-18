package book.examples.utils;

import java.time.OffsetDateTime;
import java.util.List;
import static functions.GeneratedFunctions.*;


public class AISRecord {
			
	private long MMSI;
	
	private OffsetDateTime t;
	private double latitude;
	private double longitude;
	private double SOG;
	
	
	
	private AISRecord() {
	}
	
	public static AISRecord builder(String[] aLine, List<Integer> colsPoistions) {
		AISRecord auxi = new AISRecord();
		
		try {
			auxi.t = pg_timestamptz_in(aLine[colsPoistions.get(0)], -1);
			auxi.MMSI= Long.valueOf(aLine[colsPoistions.get(1)]);
			auxi.latitude= Double.valueOf(aLine[colsPoistions.get(2)]);
			auxi.longitude= Double.valueOf(aLine[colsPoistions.get(3)]);
			auxi.SOG= Double.valueOf(aLine[colsPoistions.get(4)]);
			return auxi;
		}
		catch (Exception e) {
        // System.err.println("Invalid Record ignored " +  
		//	String.join(", ", aLine)  + e);
			return null;
		}
		

	}
	
	
	
	@Override
	public String toString() {
		return String.format("%s %s %s %s %s", t, MMSI, latitude, longitude, SOG);
	}
	

	public Long getMMSI() {
		return MMSI;
	}
	
	public long  getMillisec() {
		return t.toInstant().toEpochMilli();
	}
	
	public   OffsetDateTime getT() {
		return t;
	}
	
	public double  getLatitude() {
		return latitude;
	}
	
	public double  getLongitude() {
		return longitude;
	}
	
	public double  getSOG() {
		return SOG;
	}
}


