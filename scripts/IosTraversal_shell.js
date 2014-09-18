//Copyright (c)  2014/08/22

// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:

// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.

// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

"use strict";


UIAElement.prototype.getObjectClassName = function(){
	if (this && this.toString()) {    
    
    	var str = this.toString();
    
	    /*
	     * executed if the return of object.toString() is 
	     * "[object objectClass]"
	     */
                      
	    if(str.charAt(0) == '['){
	        var arr = str.match(/\[\w+\s*(\w+)\]/);
	    } 
	    else {
	    	/*
	    	 * executed if the return of object.constructor.toString() is 
	    	 * "function objectClass () {}"
	    	 * for IE Firefox
	     	*/
	    	var arr = str.match(/function\s*(\w+)/);
	    }
    
	    if (arr && arr.length == 2) {
	        return arr[1];
	    }
    }
    
    return undefined; 
}

UIAElement.prototype.obj2string = function(){
	var o = this;
	var r=[];
	if(typeof o=="string"){
		return "\""+o.replace(/([\'\"\\])/g,"\\$1").replace(/(\n)/g,"\\n").replace(/(\r)/g,"\\r").replace(/(\t)/g,"\\t")+"\"";
	}
	if(typeof o=="object"){
		if(!o.sort){
			for(var i in o){
				r.push(obj2string(o[i]));
			}
			if(!/^\n?function\s*toString\(\)\s*\{\n?\s*\[native code\]\n?\s*\}\n?\s*$/.test(o.toString)){
				r.push("toString:"+o.toString.toString());
			}
			r="{"+r.join()+"}\n";
		}else{
			for(var i=0;i<o.length;i++){
				r.push(obj2string(o[i]))
			}
			r="["+r.join()+"]";
		} 
		return r;
	} 
	return o.toString();
}

UIAElement.prototype.checkCanBeTapped = function(){
	if( !this.isValid() || !this.isEnabled() || !this.isVisible() 
		|| this.getObjectClassName() == "UIAStaticText"){
	//if( !this.isValid() || !this.isEnabled() || this.getObjectClassName() == "UIAStaticText"){
		/*target.pushTimeout(0);
		var ele_name = element.name();
		target.popTimeout();
		UIALogger.logMessage(getObjectClassName(element) + ":" + ele_name + " cannot be tap");*/
		return false;
	}else{
		return true;
	}
}

//ele_arr :  a array, input and output parament
UIAElement.prototype.getTappedButton = function(ele_arr){
	var root = new Array();
	root = this.elements();

	var getTappedButtonChildren = function(root,ele_arr){
		if (root instanceof UIAElementNil) {
			UIALogger.logWarning("in getTappedButton,the root node is null");
			return;
		}
		
		var elements = null;
		
		for (var i = 0; i < root.length; i++){
			var ele = root[i];
			//UIALogger.logDebug("in array: [" + i.toString() + "] " + getObjectClassName(root[i]) + " _ " + root[i].name() );
			if( ele instanceof UIAButton && ele.checkCanBeTapped()){
				ele_arr.push(ele);
			}

			elements = root[i].elements();
			if (elements instanceof UIAElementNil) {
				//UIALogger.logDebug("get the null node");
				continue;
			}else{
				getTappedButtonChildren(elements,ele_arr);
			}
		};
	}

	getTappedButtonChildren(root,ele_arr);
}

//ele_arr :  a array, input and output parament
UIAElement.prototype.getCurrentLayerElements = function(ele_arr){
	var root = new Array();
	root = this.elements();

	var getCurrentLayerElementsChildren = function(root,ele_arr){
		if (root instanceof UIAElementNil) {
			UIALogger.logWarning("in getCurrentLayerElements,the root node is null");
			return;
		}
		
		var elements = null;
		
		for (var i = 0; i < root.length; i++){
			//UIALogger.logDebug("in array: [" + i.toString() + "] " + getObjectClassName(root[i]) + " _ " + root[i].name() );

			ele_arr.push(root[i]);
			elements = root[i].elements();
			if (elements instanceof UIAElementNil) {
				//UIALogger.logDebug("get the null node");
				continue;
			}else{
				getCurrentLayerElementsChildren(elements,ele_arr);
			}
		};
	}

	getCurrentLayerElementsChildren(root,ele_arr);
}

//get all the first layer btns
UIAElement.prototype.getChildrenBtns = function(){
	var btn_eles = [];

	target.pushTimeout(0);
	var eles = this.elements();
	target.popTimeout();

	for (var i = 0; i < eles.length; i++) {
		if( eles[i] instanceof UIAButton ){
			btn_eles.push(eles[i]);
		}
	};

	return btn_eles;
}


/////-----begin------ global dict ---------
function GDict(){
	this.G_Dict = {};
	this.dict_length = 0;
}

GDict.prototype.makeDictKey = function(obj_type,obj_name,obj_position){
	var key = null;
	var str_position = null;
	str_position = obj_position.origin.x + '_' + obj_position.origin.y;
	str_position += '_' + obj_position.size.width + '_' + obj_position.size.height;

	key = obj_type + '_' + obj_name + '_' + str_position;

	return key;
}

GDict.prototype.addDict = function(obj_type,obj_name,obj_position,level){
	var key = this.makeDictKey(obj_type,obj_name,obj_position);
	//UIALogger.logDebug(key);
	var value = {};
	value["level"] = level;
	value["status"] = "undo";
	
	if(! this.G_Dict.hasOwnProperty(key)){
		this.G_Dict[key] = value;
		this.dict_length += 1;
	}
	//printDict();
}

GDict.prototype.seekDict = function(obj_type,obj_name,obj_position){
	var key = this.makeDictKey(obj_type,obj_name,obj_position);

	return this.G_Dict[key];
}

GDict.prototype.setDictElementDone = function(obj_type,obj_name,obj_position){
	//this.printDict();
	var key = this.makeDictKey(obj_type,obj_name,obj_position);
	//var value = this.G_Dict.key;
	//UIALogger.logDebug("in setDictElementDone set dict key: " + key + " done");
	this.G_Dict[key]["status"] = "done";
}

GDict.prototype.clearDict = function(){
	this.G_Dict = {};
	this.dict_length = 0;
}

GDict.prototype.printDict = function(){
	var description = "";
	for(var key in this.G_Dict){
		var property = this.G_Dict[key];
		description += key + " = " + property["level"] + '_' + property["status"] + ';\n';
	}

	UIALogger.logDebug("G_Dict length is " + this.dict_length.toString());
	UIALogger.logDebug(description);
}
/////-----end------ global dict ---------

function IosTraversal(){
	this.gdict = new GDict();
}

//prepares for tap keyboard
IosTraversal.prototype.getKeyBoardFather = function(){
	var window_arr = app.windows();

	//UIALogger.logDebug("windows length: " + window_arr.length.toString());

	for (var i = 0; i < window_arr.length; i++) {
		//UIALogger.logDebug("window_arr[" + i.toString() + "]: " + getObjectClassName(window_arr[i]))

		var window_children = window_arr[i];

		var has_keyboard = window_children.elements();

		//UIALogger.logDebug("has_keyboard: " + getObjectClassName(has_keyboard) + " length :" + has_keyboard.length.toString());

		if( !(has_keyboard instanceof UIAElementNil) ){
			for (var j = 0; j < has_keyboard.length; j++) {
				if(has_keyboard[j] instanceof UIAKeyboard){
					return window_children;
				}
			};
		}
	};

	return null;
}

IosTraversal.prototype.formatDate = function(date) {
	var yyyy = date.getFullYear();
	var mm = date.getMonth()+1;
	var dd = date.getDate();

	var H = date.getHours();
	var M = date.getMinutes();
	var S = date.getSeconds();
	var f = date.getMilliseconds();

	return [yyyy, mm, dd, H, M, S, f].join('-');
}

//calculate the keyboard "完成" points 
IosTraversal.prototype.calpoint = function(keyboard){
	var point = {};

	var rect = keyboard.rect();

	point.x = rect.size.width - 5;
	point.y = rect.origin.y -5;

	return point;
}

//input string to the textfield and dismiss the keyboard
IosTraversal.prototype.inputString = function(test_string){
	var keyboard = app.keyboard();

	if( !(keyboard instanceof UIAElementNil) ){

		keyboard.typeString(test_string);

		var point = this.calpoint(keyboard);

		var done_btn = null;

		var keyboard_father = this.getKeyBoardFather();

		if(keyboard_father != null){		
			//keyboard_father.logElementTree();
			
			var toolbar_arr = keyboard_father.toolbars();

			UIALogger.logDebug("toolbar_arr length is " + toolbar_arr.length.toString());

			if( toolbar_arr instanceof UIAElementNil ){
				//tap point
				UIALogger.logDebug("toolbar_arr is UIAElementNil");
				target.tap(point);
			}else{ //tap button
				for (var i = 0; i < toolbar_arr.length; i++) {
					if( toolbar_arr[i].buttons()["完成"] == undefined){
						UIALogger.logDebug( "toolbar_arr[" + i.toString() + "] not match" );
						continue;
					}else{
						UIALogger.logDebug( "toolbar_arr[" + i.toString() + "] find !!!!" );
						done_btn = toolbar_arr[i].buttons()["完成"];
						break;
					}
				};

				//UIALogger.logDebug("done_btn type is : " + getObjectClassName(done_btn));

				if(done_btn != null){
					done_btn.tap();
				}else{
					//tap point;
					UIALogger.logDebug("done_btn is null");
					target.tap(point);
				}
			}
		}else{
			UIALogger.logDebug("get getKeyBoardFather null");
			target.tap(point);
		}
	}
}

IosTraversal.prototype.rmDoneElements = function(ele_arr,level){
	var new_dict = {};
	var new_arr = [];

	var obj_type = null;
	var obj_name = null;
	var obj_position = null;

	for (var i = 0; i <= ele_arr.length - 1; i++) {			
		var test = ele_arr[i];
		
		//UIALogger.logDebug("in rmDoneElements " + i.toString());
		
		if( ele_arr[i] instanceof UIAElementNil) {
			UIALogger.logWarning("null node,not process");
			continue;
		}
		
		target.pushTimeout(0);
		obj_name = ele_arr[i].name();
		obj_position = ele_arr[i].rect();
		target.popTimeout();
		obj_type = ele_arr[i].getObjectClassName();

		//UIALogger.logDebug("obj_type: " + obj_type);

		if(obj_type === undefined){
			UIALogger.logWarning("when rmDoneElements " + obj_name + '_' + obj_position + "type is undefined");
			continue;
		}else{
			if( ele_arr[i].checkCanBeTapped() ){
				//assume only one navigationbar and uiatabbar in window
				if( obj_type == "UIANavigationBar" ){
					UIALogger.logMessage("add UIANavigationBar to dict");
					new_dict.navigationbar = ele_arr[i];
				}
				if( obj_type == "UIATabBar" ){
					UIALogger.logMessage("add UIATabBar to dict");
					new_dict.tabbar = ele_arr[i];
				}
				if( obj_type == "UIAToolbar" ){
					UIALogger.logMessage("add UIAToolbar to dict");
					new_dict.toolbar = ele_arr[i];
				}

				var value = this.gdict.seekDict(obj_type,obj_name,obj_position);
				if(undefined == value){
					//UIALogger.logDebug("seekDict not find result, so add to rmDoneElements array");
					new_arr.push(ele_arr[i]);
					this.gdict.addDict(obj_type,obj_name,obj_position,level);
				}else{
					//UIALogger.logDebug("status: " + value["status"] + "-----" + "level: " + value["level"]);
					if(value["status"] == "undo"){
						new_arr.push(ele_arr[i]);
						//UIALogger.logDebug("seekDict status is undo, so add to rmDoneElements array");
					}else{
						//UIALogger.logDebug("seekDict status is done, so don't add to rmDoneElements array");
					}
				}
			}else{
				//UIALogger.logMessage(obj_type + ":" + obj_name + " cannot be tapped,so donn't add to G_Dict and rm in current_undo_element_arr" );
			}
		}
	};

	new_dict.undo_arr = new_arr;

	return new_dict;
}

IosTraversal.prototype.genRandomPoint = function(x,y,width,height){
	var point = {};
	point.x = x + Math.random() * width;
	point.y = y + Math.random() * height;

	return point;
}

//all tappable elements be tapped, so tap points
IosTraversal.prototype.desperateTry = function(level){

	UIALogger.logMessage("in desperateTry");

	var all_ele_arr = [];
	var navi_eles_btns = [];
	var tabbar_eles_btns = [];
	var toolbar_eles_btns = [];


	var navigationBar = app.navigationBar();
	if( !(navigationBar instanceof UIAElementNil) ){
		navi_eles_btns = navigationBar.getChildrenBtns();
		UIALogger.logDebug("navi_eles_btns length: " + navi_eles_btns.length.toString());
	}else{
		UIALogger.logDebug("navigationbar is nil");
	}

	var tabBar = app.tabBar();
	if( !(tabBar instanceof UIAElementNil) ){
		tabbar_eles_btns = tabBar.getChildrenBtns();
		UIALogger.logDebug("tabbar_eles_btns length: " + tabbar_eles_btns.length.toString());
	}else{
		UIALogger.logDebug("tabBar is nil");
	}

	var toolbar = app.toolbar();
	if( !(toolbar instanceof UIAElementNil) ){
		toolbar_eles_btns = toolbar.getChildrenBtns();
		UIALogger.logDebug("toolbar_eles_btns length: " + toolbar_eles_btns.length.toString());
	}else{
		UIALogger.logDebug("toolbar is nil");
	}

	var tmp_arr = navi_eles_btns.concat(tabbar_eles_btns);
	all_ele_arr = tmp_arr.concat(toolbar_eles_btns);

	UIALogger.logDebug("all_ele_arr length: " + all_ele_arr.length.toString());

	if(all_ele_arr.length > 0){
		var ran_index = Math.floor( (Math.random() * all_ele_arr.length) );

		UIALogger.logDebug("ran_index : " + ran_index.toString());

		target.pushTimeout(0);
		var obj_position = all_ele_arr[ran_index].rect();
		target.popTimeout();

		var point = {};
		point.x = obj_position.origin.x + obj_position.size.width / 2;
		point.y = obj_position.origin.y + obj_position.size.height / 2;

		UIALogger.logDebug("tap unvisiable element points");
		try{
			target.tap(point);
		}catch(e){
			UIALogger.logWarning("tap fail!!!");
		}

		target.delay(1);
		this.traversalTree(level+1);
	}else{
		UIALogger.logDebug("tap random points");
		try{
			target.tap(this.genRandomPoint(10,10,50,50));
		}catch(e){
			UIALogger.logWarning("tap fail!!!!");
		}
		target.delay(1);
		this.traversalTree(level+1);
	}
}

//use events to represent element
IosTraversal.prototype.traversalTree = function(level){
	//window.logElementTree();

	//target.delay(1);

	/*var keyboard = app.keyboard();
	if( !(keyboard instanceof UIAElementNil) ){
		this.inputString("test");
		UIALogger.logDebug("maybe textfield, inputString test");
	}*/

	var target = UIATarget.localTarget();
	var app = target.frontMostApp();
	var window = app.mainWindow();

	g_tap_count += 1;

	UIALogger.logMessage("g_tap_count : " + g_tap_count.toString());

	if(g_tap_count >= TAP_THRESHOLD){
		return;
	}

	var filename = "traversal-" + this.formatDate(new Date());
	target.captureScreenWithName(filename);

	/*var alert = app.alert()
	if( !(alert instanceof UIAElementNil) ){
		alert.defaultButton().tap();
		target.delay(1);
	}*/

	var current_all_element_arr = [];
	var current_undo_element_dict = {};
	var current_undo_element_arr = [];

	var navigationbar_button_arr = [];
	var tabbar_button_arr = [];
	var toolbar_button_arr = [];
	var last_tapped_button_arr = [];  //merge navigationbar_button_arr and tabbar_button_arr

	target.pushTimeout(0);
	window.getCurrentLayerElements(current_all_element_arr);
	target.popTimeout();
	
	UIALogger.logMessage("current_all_element_arr length: " + current_all_element_arr.length.toString());
	/*for (var i = 0; i < current_all_element_arr.length; i++) {
		UIALogger.logDebug("current_all_element_arr: " + getObjectClassName(current_all_element_arr[i]));
	};*/
	
	current_undo_element_dict = this.rmDoneElements(current_all_element_arr,level);
	current_undo_element_arr = current_undo_element_dict.undo_arr;
	var navigationbar = current_undo_element_dict.navigationbar;
	if( navigationbar != undefined){
		target.pushTimeout(0);
		navigationbar.getTappedButton(navigationbar_button_arr);
		target.popTimeout();
	}

	var tabbar = current_undo_element_dict.tabbar;
	if( tabbar != undefined){
		target.pushTimeout(0);
		tabbar.getTappedButton(tabbar_button_arr);
		target.popTimeout();
	}

	var toolbar = current_undo_element_dict.toolbar;
	if( toolbar != undefined){
		target.pushTimeout(0);
		toolbar.getTappedButton(toolbar_button_arr);
		target.popTimeout();
	}

	var tmp_arr = navigationbar_button_arr.concat(tabbar_button_arr);
	last_tapped_button_arr = tmp_arr.concat(toolbar_button_arr);

	/*for (var i = 0; i < current_undo_element_arr.length; i++) {
		UIALogger.logDebug("current_undo_element_arr: " + getObjectClassName(current_all_element_arr[i]) + ':' +  current_all_element_arr[i].name());
	};*/

	UIALogger.logMessage("current_undo_element_arr length: " + current_undo_element_arr.length.toString());
	//UIALogger.logDebug("navigationbar_button_arr length: " + navigationbar_button_arr.length.toString());
	//UIALogger.logDebug("tabbar_button_arr length: " + tabbar_button_arr.length.toString());
	UIALogger.logMessage("last_tapped_button_arr length: " + last_tapped_button_arr.length.toString());

	if(current_undo_element_arr.length <= 0){

		if(last_tapped_button_arr.length > 0){
			var random_index = Math.floor( (Math.random() * last_tapped_button_arr.length) );
			UIALogger.logMessage("after traversal all node, start random[" + random_index.toString() + "] visit tabbar or navigationbar button");
			UIALogger.logMessage("level[" + level.toString() + "]:  " + "tap " 
				+  last_tapped_button_arr[random_index].getObjectClassName()  + ":" + last_tapped_button_arr[random_index].name());
			target.pushTimeout(2);
			last_tapped_button_arr[random_index].tap();
			target.popTimeout();

			target.delay(1);
			this.traversalTree(level+1);
			//return;
		}
		else{
			UIALogger.logMessage("level[" + level.toString() + "]:  " + "current_undo_element_arr is empty.");

			this.desperateTry(level);

			this.traversalTree(level+1);

			//because no back key in ios,so can't back to previous ui 
			//return means exit the program
			//return;
		}
	}else{	
		var i = Math.floor( (Math.random() * current_undo_element_arr.length) );

		UIALogger.logDebug( "in traversalTree random index: " + i.toString());
		target.pushTimeout(0);
		var obj_name = current_undo_element_arr[i].name();
		var obj_position = current_undo_element_arr[i].rect();
		target.popTimeout();
		var obj_type = current_undo_element_arr[i].getObjectClassName();
		if( obj_type === undefined ){
			UIALogger.logWarning("level[" + level.toString() + "]:  " + obj_type + " is undefined");
			traversalTree(level+1);
		}else{
			var value = this.gdict.seekDict(obj_type,obj_name,obj_position);
			if(value === undefined){ //don't know why this!!
				var key = this.gdict.makeDictKey(obj_type,obj_name,obj_position);
				UIALogger.logMessage("seekDict " + key + " null, amazing...");

				if(current_undo_element_arr[i].checkCanBeTapped()){
					this.gdict.addDict(obj_type,obj_name,obj_position,level);

					UIALogger.logMessage("level[" + level.toString() + "]:  " + "tap " + obj_type + ":" + obj_name);
						/*UIALogger.logDebug("isValid: " + current_undo_element_arr[i].isValid().toString() +
							" isEnabled: " + current_undo_element_arr[i].isEnabled().toString() +
							" isVisible: " + current_undo_element_arr[i].isVisible().toString());
						*/
					if( obj_name != "夜间模式"){
						target.pushTimeout(2);
						current_undo_element_arr[i].tap();
						target.popTimeout();

						if( obj_type == "UIASecureTextField" || obj_type == "UIATextField" || obj_type == "UIATextView"){
							this.inputString("test");
						}
					}else{
						UIALogger.logMessage("夜间模式, not tap");
					}

					this.gdict.setDictElementDone(obj_type,obj_name,obj_position);

					target.delay(1);			
				}

				this.traversalTree(level+1);
			}else{
				if(value["status"] == "undo"){
						//UIALogger.logDebug(value["level"] + '_' + value["status"]);
					UIALogger.logDebug("level[" + level.toString() + "]:  " + "tap " + obj_type + ":" + obj_name);
						/*UIALogger.logDebug("isValid: " + current_undo_element_arr[i].isValid().toString() +
							" isEnabled: " + current_undo_element_arr[i].isEnabled().toString() +
							" isVisible: " + current_undo_element_arr[i].isVisible().toString()); */
					if( !current_undo_element_arr[i].checkCanBeTapped() 
						|| obj_name == "夜间模式" ){
						UIALogger.logMessage("夜间模式 or can't be tap, not tap: " + obj_name);
						this.gdict.setDictElementDone(obj_type,obj_name,obj_position);
					}else{
						try{
							this.gdict.setDictElementDone(obj_type,obj_name,obj_position);
							target.pushTimeout(2);
							current_undo_element_arr[i].tap();  //tap maybe throw exception
							target.popTimeout();

							target.delay(1);

							if( obj_type == "UIASecureTextField" || obj_type == "UIATextField" || obj_type == "UIATextView"){
								this.inputString("test");
							}	
						}catch(e){
							UIALogger.logWarning("could not tapped!! tap fail");
						}	
					}		
				}else{
					UIALogger.logMessage("level[" + level.toString() + "]:  "  + obj_type + ":" + obj_name + " is done, continue for");
				}

				this.traversalTree(level+1);
			}
		}
	}

	//this.gdict.printDict();	
}

IosTraversal.prototype.startTraversal = function(){
	this.traversalTree(0);
	UIALogger.logMessage("end all traversal");
}

var g_tap_count = 0;
var TAP_THRESHOLD = 100;

var target = UIATarget.localTarget();
var app = target.frontMostApp();
var window = app.mainWindow();

var iostraversal = new IosTraversal();

iostraversal.gdict.clearDict();
iostraversal.startTraversal();
