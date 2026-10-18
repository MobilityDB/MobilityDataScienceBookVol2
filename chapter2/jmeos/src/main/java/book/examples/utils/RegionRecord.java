package book.examples.utils;

import static functions.GeneratedFunctions.geom_in; 
import java.util.List;
import jnr.ffi.Pointer;

public class RegionRecord {
	private String name;
	private Pointer geom;
	private String geomAsString;
		
	private RegionRecord() {
	}
	
	public static RegionRecord builder(String aLine[], List<Integer> colPositions)
    {
		RegionRecord auxi = new RegionRecord();
		
		// Order of strings: id name population geom
		try {
			auxi.name= aLine[colPositions.get(0)];
			auxi.geom = geom_in(aLine[colPositions.get(1)], -1);
			auxi.geomAsString=aLine[colPositions.get(1)];
			if (auxi.geom == null) {
                 System.out.println("Failed to parse geometry for region " + auxi.name);
                 return null;
             }
			
			return auxi;
		}
		catch (Exception e) {
			System.err.println("Invalid Record ignored " +  
					String.join(", ", aLine)  + e);
			return null;
		}
	}
	
	public String getName() {
		return name;
	}
	
	public Pointer getGeom() {
		return geom;
	}
	
	@Override
	public String toString() {
		return String.format("%s %s", name, geomAsString);
	}
}
