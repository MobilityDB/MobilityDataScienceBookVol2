package book.examples.utils;

import static functions.GeneratedFunctions.geom_in;
import java.util.List;
import jnr.ffi.Pointer;

public class CommuneRecord {
	private int id;
	private String name;
	private int population;
	private Pointer geom;
	private String geomAsString;
		
	private CommuneRecord() {
	}
	
	public static CommuneRecord builder(String aLine[], List<Integer> colPositions)
    {
		CommuneRecord auxi = new CommuneRecord();
		
		// Order of strings: id name population geom
		try {
			auxi.id= Integer.valueOf(aLine[colPositions.get(0)]);
			auxi.name= aLine[colPositions.get(1)];
			auxi.population= Integer.valueOf(aLine[colPositions.get(2)]);
			auxi.geom = geom_in(aLine[colPositions.get(3)], -1);
			auxi.geomAsString=aLine[colPositions.get(3)];
			 if (auxi.geom == null) {
                 System.out.println("Failed to parse geometry for commune " + auxi.name);
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
	

	public Pointer getGeom() {
		return geom;
	}
	
	public String getName() {
		return name;
	}
	
	@Override
	public String toString() {
		return String.format("%d %s %d %s", id, name, population, geomAsString);
	}
}
