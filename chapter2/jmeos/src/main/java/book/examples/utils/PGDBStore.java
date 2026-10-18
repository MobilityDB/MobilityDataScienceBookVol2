package book.examples.utils;

import java.sql.Connection; 
import java.sql.PreparedStatement;
import java.sql.SQLException;
import java.util.ArrayList;

import org.postgresql.PGProperty;
import org.postgresql.ds.PGSimpleDataSource;

public class PGDBStore {

	private PGSimpleDataSource ods = new PGSimpleDataSource ();
	private Connection conn;
	
	public PGDBStore() {
		// // host.docker.internal,  localhost, etc
		ods.setProperty(PGProperty.PG_HOST, env("PGHOST", "host.docker.internal"));  
		ods.setProperty(PGProperty.PG_DBNAME, null );
		ods.setProperty(PGProperty.PG_PORT, env("PGPORT", "6666"));
		ods.setProperty(PGProperty.USER, env("PGUSER", "postgres"));
		ods.setProperty(PGProperty.PASSWORD, env("PGPASSWORD", "postgres"));
	}
	
	public void createDatabase(String dbName) throws SQLException {
		Connection conn = ods.getConnection();
		
		PreparedStatement pstmt;
		// CREATE DATABASE IF NOT EXISTS is not possible in PG
		// Try to create it. If it fails, try to connect to and existing DB
		String strQuery = "CREATE DATABASE " + dbName;
		
		try {
			pstmt = conn.prepareStatement(strQuery);
			pstmt.executeUpdate();
		}
		catch (Exception e) {
			System.out.println(e);
			System.out.printf("Trying to connect to %s DB", dbName);
		}
		
		connectToDatabase(dbName);
	}
	
	public void connectToDatabase(String dbName) throws SQLException  {
		ods.setProperty(PGProperty.PG_DBNAME, dbName);
		conn = ods.getConnection();
		
		String strQuery = "CREATE EXTENSION IF NOT EXISTS MobilityDB CASCADE";
		
		PreparedStatement pstmt = conn.prepareStatement(strQuery);
		pstmt.executeUpdate();
	}
	
	
	public void createShipsTable() throws SQLException {
		String strQuery= "CREATE SCHEMA IF NOT EXISTS jmeos";
		PreparedStatement pstmt = conn.prepareStatement(strQuery);
		pstmt.executeUpdate();
		
		strQuery= "DROP TABLE IF EXISTS jmeos.Ships";
		pstmt = conn.prepareStatement(strQuery);
		pstmt.executeUpdate();
		
		strQuery= "CREATE TABLE jmeos.Ships " +
				"(MMSI integer, Trajectory tgeogpoint, SOG tfloat)"; 
		
		pstmt = conn.prepareStatement(strQuery);
		pstmt.executeUpdate();
		System.out.println("CREATING TABLE jmeos.Ships ...");
	}
	
	public void populateShipsTable(ArrayList<ShipRecord> tripRecords) throws SQLException {

		String strQuery= "INSERT INTO jmeos.Ships "
				+ "(MMSI, Trajectory, SOG) "
				+ "VALUES (?, ?, ?)";
		PreparedStatement pstmt = conn.prepareStatement(strQuery);
		
		int rows= 0;
		for (ShipRecord shipRecord : tripRecords) {
			

  			pstmt.setLong(1, shipRecord.getMMSI());
			pstmt.setObject(2, shipRecord.getTripAsString(), java.sql.Types.OTHER);
			pstmt.setObject(3, shipRecord.getSOGAsString(), java.sql.Types.OTHER);
				

		// alternatively
/*			String strQuery= String.format("INSERT INTO jmeos.Ships "
					+ "(MMSI, Trajectory, SOG) "
					+ "VALUES (%d, '%s', '%s')", 
					shipRecord.getMMSI(),
					shipRecord.getTripAsString(),
					shipRecord.getSOGAsString()
					)
					;
		//	System.out.println(strQuery);
			PreparedStatement pstmt = conn.prepareStatement(strQuery);
*/
			
			rows+= pstmt.executeUpdate();
		}
		System.out.printf("Finished. %d number of tuples inserted.\n", rows);
	}
	
	
	// The value of an environment variable, or its default when it is not set
	private static String env(String name, String dflt) {
		String v = System.getenv(name);
		return v != null && !v.isEmpty() ? v : dflt;
	}
}
