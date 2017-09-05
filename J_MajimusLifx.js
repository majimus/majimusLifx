var Lifx = (function (api) {
	
	var lifx_svs = 'urn:majimus-com:serviceId:Lifx';

	
	var myModule = {};
	
	var deviceID = api.getCpanelDeviceId();
	
	var curChild = {};
	
	function SetCurrent() {
		var devices = api.getListOfDevices();
		for (i=0; i<devices.length; i+=1) {
				var devid = devices[i].id;
				if(devices[i].id_parent == deviceID) {
					var id = api.getDeviceState(devid, lifx_svs, 'LightId');
					curChild[id] = "seen";
				}			
		}
	}
	
	function onBeforeCpanelClose(args){
        //console.log('handler for before cpanel close');
    }
    
	function init(){
        api.registerEventHandler('on_ui_cpanel_before_close', myModule, 'onBeforeCpanelClose');
    }
	
	function api_key_set(varVal) {
	  api.setDeviceStateVariablePersistent(deviceID, lifx_svs, "ApiKey", varVal, 0);
	}
	
	function light_id_set(varVal) {
	  api.setDeviceStateVariablePersistent(deviceID, lifx_svs, "LightId", varVal, 0);
	}
	
	function api_key_set_par(varVal) {
	  api.setDeviceStateVariablePersistent(deviceID, lifx_svs, "ApiKey", varVal, 0);
	}
	
	function ReloadEngine(){
		api.luReload();
	}
	
	/*	This was used on the old version with a custom
		JSON for the bulb, went back to using a built in
		so it would work on mobile devices 
	*/
	function LifxSettings(){
		try {
			init();			
			var key  = api.getDeviceState(deviceID, lifx_svs, 'ApiKey');
			var id = api.getDeviceState(deviceID, lifx_svs, 'LightId');			
			var html =  '<table>' +
			'<tr><td>API Key</td><td><input  type="text" id="api_key" size=20 value="' + key + '" onchange="Lifx.api_key_set(this.value);"></td></tr>' +
			'<tr><td>Light ID</td><td><input  type="text" id="light_id" size=20 value="' + id + '" onchange="Lifx.light_id_set(this.value);"></td></tr>' +
			'</table>';
			html += '<input type="button" value="Save and Reload" onClick="Lifx.ReloadEngine()"/>';
			api.setCpanelContent(html);
		} catch (e) {
            Utils.logError('Error in Lifx.LifxSettings(): ' + e);
        }
	}
	
	function SceneToForm(id,name) {
		var id = "scene_id:"+id;
		var cstat = "";
		
		if(curChild[id]) {
			cstat = 'checked=""';
		}
		
		var item = '<input type="checkbox" class="list" value="'+id+','+name+',scene" '+cstat+'/>'+name+'<br>';
		jQuery('#light_list').append(item);
	}	
	
	function ListScenes() {
		var key = jQuery('#api_key').val();	    
		jQuery.ajax({ 
             type: "GET",
			 dataType: "json",
             url: "https://api.lifx.com/v1/scenes",
			 headers:{
				 "Authorization" : "Bearer "+key,
				 "Content-Type"  : "application/json",
				 "Content-Length" : 0
			 },
			 success: function(data){        
                console.log(data);
				jQuery.each(data,function(i,obj){
					SceneToForm(obj.uuid,obj.name);
				});
		}});
	}
	
    function LightToForm(id,name) {
		var id = "id:"+id;
		var cstat = "";
		
		if(curChild[id]) {
			cstat = 'checked=""';
		}
		
		var item = '<input type="checkbox" class="list" value="'+id+','+name+',bulb" '+cstat+'/>'+name+'<br>';
		jQuery('#light_list').append(item);
	}	
	
	function ListLights() {
		SetCurrent();
		jQuery('#light_list').html("");
		var key = jQuery('#api_key').val();	    
		jQuery.ajax({ 
             type: "GET",
			 dataType: "json",
             url: "https://api.lifx.com/v1/lights/all",
			 headers:{
				 "Authorization" : "Bearer "+key,
				 "Content-Type"  : "application/json",
				 "Content-Length" : 0
			 },
			 success: function(data){        
                console.log(data);
				jQuery.each(data,function(i,obj){
					LightToForm(obj.id,obj.label);
				});
		}});
		ListScenes();		
	}
	
	function SaveSelection() {
		var count = 0;
		var data = "";		
		jQuery(".list").each(function()
		{
			if(jQuery(this).is(':checked'))
            {
				count = count + 1;
				if(count>1)
				{
					data = data + ",";
				}
				data = data + jQuery(this).val();
			}
		});
		api.setDeviceStateVariablePersistent(deviceID, lifx_svs, "ChildCount", count, 0);
		api.setDeviceStateVariablePersistent(deviceID, lifx_svs, "ChildData", data, 0);
		
		if(count>0){
			ReloadEngine();
		}
	}
	
	function ParentSettings() {
		try {
			init();			
			var key  = api.getDeviceState(deviceID, lifx_svs, 'ApiKey');	
			var html =  '<table>' +
			'<tr><td>API Key</td><td><input  type="text" id="api_key" size=20 value="' + key + '" onchange="Lifx.api_key_set_par(this.value);"></td></tr>' +
			'</table>';
			html += '<p><input type="button" value="List Devices" onClick="Lifx.ListLights()"/></p>';
			html += '<p><form id="light_list"></form></p>';
			html += '<input type="button" value="Sync Selection" onClick="Lifx.SaveSelection()"/>';
			html += '<p>WARNING: unchecked devices will be removed</p>';
			html += '<p>WARNING: if previously added!!</p>';
			api.setCpanelContent(html);
		} catch (e) {
            Utils.logError('Error in Lifx.ParentSettings(): ' + e);
			console.log("Critical error");
        }
	}
	
	///////////////////////////
	myModule = {
		init : init,
		onBeforeCpanelClose: onBeforeCpanelClose,
		LifxSettings: LifxSettings,
		api_key_set: api_key_set,
		light_id_set : light_id_set,
		ParentSettings : ParentSettings,
		ReloadEngine: ReloadEngine,
		ListLights: ListLights,
		api_key_set_par: api_key_set_par,
		LightToForm: LightToForm,
		SaveSelection: SaveSelection,
		ListScenes: ListScenes,
		SceneToForm: SceneToForm
	};

	return myModule;

})(api);