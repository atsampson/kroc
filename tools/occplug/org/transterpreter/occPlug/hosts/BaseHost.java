package org.transterpreter.occPlug.hosts;

import org.gjt.sp.jedit.jEdit;
import org.transterpreter.occPlug.OccPlugPlugin;

/*
 * BaseHost.java
 * part of the occPlug plugin for the jEdit text editor
 * Copyright (C) 2010 Christian L. Jacobsen
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
 */

public abstract class BaseHost {

	protected String[] commandBase;
	protected String base;
	
	protected BaseHost()
	{
		commandBase = new String[] {"default"};
	}
	
	protected BaseHost(String base)
	{
		this.base = base;
		commandBase = new String[] {base, "default"};
	}

	public void hostStartup() {
		/* Do nothing here... just override. */
	}
	
	/**
	 * Provide a list of suggestions for available serial ports. 
	 * This is just a list of suggestions and the user will be able to
	 * enter their own port.
	 * 
	 * This implementation returns null, should be overridden to return sensible
	 * suggestions if this is possible.
	 * 
	 * @return a list of serial port names or null if no suggestions.
	 */
	public String[] getSerialPorts()
	{
		return null;
	}
	
	public String getCommandName(String command)
	{
		String prop = "";
		
		for(final String base : commandBase)
		{
			prop = OccPlugPlugin.PROPERTY_PREFIX + "command." + base + "." + command;
			String cmd = jEdit.getProperty(prop);
			if(cmd != null)
				return cmd;
		}
		
		throw new RuntimeException("Invalid command: " + command + "(" + prop + ")");		
	}
	
	public String getPath(String tool, String path, String defaultValue)
	{
		String prop = OccPlugPlugin.PROPERTY_PREFIX + "path." + tool + "." + base + "." + path;
		String cmd = jEdit.getProperty(prop);
		if(cmd != null)
			return cmd;
		
		return defaultValue;
	}
	
	public String getPath(String tool, String path)
	{
		String prop = OccPlugPlugin.PROPERTY_PREFIX + "path." + tool + "." + base + "." + path;
		String cmd = jEdit.getProperty(prop);
		if(cmd != null)
			return cmd;
		
		throw new RuntimeException("Invalid getPath: (" + prop + ")");		
	}
	
	public static BaseHost getHostObject()
	{
		String os = System.getProperty("os.name");
		
		if(os.equals("OS X") || os.equals("Mac OS X"))
		{
			return new OSX();
		}
		else if(os.startsWith("Windows"))
		{
			return new Windows();
		}
		else if(os.equals("Linux"))
		{
			String prop = OccPlugPlugin.PROPERTY_PREFIX + "linux.flavor";
			/* On Linux, this property file does not auto-load.
			 * I'm forcing the issue by asking jEdit to get the resource.
			 */ 
			jEdit.class.getResource("ubuntu.props");

			if (jEdit.getProperty(prop).equals("ubuntu"))
			{
				return new Ubuntu();
			} else {
				throw new RuntimeException("Linux not supported.");
			}
		}
		
		throw new RuntimeException("Unknown operating system");
	}
}
