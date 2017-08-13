var Lifx = (function (api) {
	var lifx_svs = 'urn:majimus-com:serviceId:Lifx';
	var myModule = {};
	
	var deviceID = api.getCpanelDeviceId();
	
	function onBeforeCpanelClose(args){
        //console.log('handler for before cpanel close');
    }
    
	function init(){
        // register to events...
        api.registerEventHandler('on_ui_cpanel_before_close', myModule, 'onBeforeCpanelClose');
    }
	
	///////////////////////////
	function api_key_set(varVal) {
	  api.setDeviceStateVariablePersistent(deviceID, lifx_svs, "ApiKey", varVal, 0);
	}
	
	function light_id_set(varVal) {
	  api.setDeviceStateVariablePersistent(deviceID, lifx_svs, "LightId", varVal, 0);
	}
	
	function ReloadEngine(){
		api.luReload();
	}
	
	function LifxSettings() {
		//TODO: put a light chooser for next version of plugin.
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
	///////////////////////////
	myModule = {
		init : init,
		onBeforeCpanelClose: onBeforeCpanelClose,
		LifxSettings: LifxSettings,
		api_key_set: api_key_set,
		light_id_set : light_id_set,
		ReloadEngine: ReloadEngine
	};

	return myModule;

})(api);