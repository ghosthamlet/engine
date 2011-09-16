package org.flixel;

import flash.errors.Error;
#if flash
import flash.events.NetStatusEvent;
import flash.net.SharedObjectFlushStatus;
#end

import flash.net.SharedObject;

/**
 * A class to help automate and simplify save game functionality.
 * Basicaly a wrapper for the Flash SharedObject thing, but
 * handles some annoying storage request stuff too.
 */
class FlxSave implements Dynamic
{
	#if flash
	static private var SUCCESS:UInt = 0;
	static private var PENDING:UInt = 1;
	static private var ERROR:UInt = 2;
	#else
	static private var SUCCESS:Int = 0;
	static private var PENDING:Int = 1;
	static private var ERROR:Int = 2;
	#end
	/**
	 * Allows you to directly access the data container in the local shared object.
	 * @default null
	 */
	public var data:Dynamic;
	/**
	 * The name of the local shared object.
	 * @default null
	 */
	public var name:String;
	/**
	 * The local shared object itself.
	 * @default null
	 */
	#if flash9
	private var _sharedObject:SharedObject;
	#else
	private var _sharedObject:Dynamic;
	#end
	
	/**
	 * Internal tracker for callback function in case save takes too long.
	 */
	private var _onComplete:Dynamic;
	/**
	 * Internal tracker for save object close request.
	 */
	private var _closeRequested:Bool;
	
	/**
	 * Blanks out the containers.
	 */
	public function new()
	{
		destroy();
	}

	/**
	 * Clean up memory.
	 */
	public function destroy():Void
	{
		_sharedObject = null;
		name = null;
		data = null;
		_onComplete = null;
		_closeRequested = false;
	}
	
	/**
	 * Automatically creates or reconnects to locally saved data.
	 * @param	Name	The name of the object (should be the same each time to access old data).
	 * @return	Whether or not you successfully connected to the save data.
	 */
	public function bind(Name:String):Bool
	{
		destroy();
		name = Name;
		try
		{
			//#if flash9
			_sharedObject = SharedObject.getLocal(name);
			//#else
			//return false;
			//#end
		}
		catch(e:Error)
		{
			FlxG.log("ERROR: There was a problem binding to\nthe shared object data from FlxSave.");
			destroy();
			return false;
		}
		data = _sharedObject.data;
		return true;
	}
	
	/**
	 * A way to safely call <code>flush()</code> and <code>destroy()</code> on your save file.
	 * Will correctly handle storage size popups and all that good stuff.
	 * If you don't want to save your changes first, just call <code>destroy()</code> instead.
	 * @param	MinFileSize		If you need X amount of space for your save, specify it here.
	 * @param	OnComplete		This callback will be triggered when the data is written successfully.
	 * @return	The result of result of the <code>flush()</code> call (see below for more details).
	 */
	public function close(	
							#if flash
							?MinFileSize:UInt = 0, 
							#else
							?MinFileSize:Int = 0, 
							#end
							?OnComplete:Dynamic = null):Bool
	{
		_closeRequested = true;
		return flush(MinFileSize, OnComplete);
	}

	/**
	 * Writes the local shared object to disk immediately.  Leaves the object open in memory.
	 * @param	MinFileSize		If you need X amount of space for your save, specify it here.
	 * @param	OnComplete		This callback will be triggered when the data is written successfully.
	 * @return	Whether or not the data was written immediately.  False could be an error OR a storage request popup.
	 */
	public function flush(	
							#if flash
							?MinFileSize:UInt = 0, 
							#else
							?MinFileSize:Int = 0, 
							#end
							?OnComplete:Dynamic = null):Bool
	{
		if (!checkBinding())
		{
			return false;
		}
		_onComplete = OnComplete;
		var result:String = null;
		try { result = _sharedObject.flush(MinFileSize); }
		catch (e:Error) { return onDone(ERROR); }
		#if flash
		if (result == SharedObjectFlushStatus.PENDING)
		{
			_sharedObject.addEventListener(NetStatusEvent.NET_STATUS, onFlushStatus);
		}
		#end
		return onDone((
						#if flash
						result == SharedObjectFlushStatus.FLUSHED
						#else
						result == "flushed"
						#end
						) ? SUCCESS : PENDING);
	}
	
	/**
	 * Erases everything stored in the local shared object.
	 * Data is immediately erased and the object is saved that way,
	 * so use with caution!
	 * @return	Returns false if the save object is not bound yet.
	 */
	public function erase():Bool
	{
		if (!checkBinding())
		{
			return false;
		}
		_sharedObject.clear();
		return true;
	}
	
	/**
	 * Event handler for special case storage requests.
	 * @param	E	Flash net status event.
	 */
	#if flash
	private function onFlushStatus(E:NetStatusEvent):Void
	{
		_sharedObject.removeEventListener(NetStatusEvent.NET_STATUS, onFlushStatus);
		onDone((E.info.code == "SharedObject.Flush.Success")?SUCCESS:ERROR);
	}
	#end
	
	/**
	 * Event handler for special case storage requests.
	 * Handles logging of errors and calling of callback.
	 * @param	Result		One of the result codes (PENDING, ERROR, or SUCCESS).
	 * @return	Whether the operation was a success or not.
	 */
	private function onDone(
								#if flash
								Result:UInt
								#else
								Result:Int
								#end
								):Bool
	{
		switch(Result)
		{
			case PENDING:
				FlxG.log("FLIXEL: FlxSave is requesting extra storage space.");
			case ERROR:
				FlxG.log("ERROR: There was a problem flushing\nthe shared object data from FlxSave.");
			//default:
		}
		if (_onComplete != null)
		{
			_onComplete(Result == SUCCESS);
		}
		if (_closeRequested)
		{
			destroy();			
		}
		return Result == SUCCESS;
	}
	
	/**
	 * Handy utility function for checking and warning if the shared object is bound yet or not.
	 * @return	Whether the shared object was bound yet.
	 */
	private function checkBinding():Bool
	{
		if(_sharedObject == null)
		{
			FlxG.log("FLIXEL: You must call FlxSave.bind()\nbefore you can read or write data.");
			return false;
		}
		return true;
	}
}