//#import "./common.js"

target = UIATarget.localTarget();
app = target.frontMostApp();
win = app.mainWindow();
host = target.host();

UIALogger.logStart("The case is running.");

var step = 1;
var isEnd = false;
var sendToServer ="Get the next step.";

try {
    UIATarget.localTarget().captureScreenWithName("" + step);
    while(!isEnd){
        step++;
        UIATarget.localTarget().captureScreenWithName("" + step);
    
        var result = host.performTaskWithPathArgumentsTimeout("/bin/sh",["xxxxx/TcpSocket.sh"],5);
        var stdout = result.stdout.split("$");
        var type = stdout[0];
        
        if (type == "record"){
            sendToServer = eval(stdout[1]);
            
            for (var i = 0;i < 5;i++){
                step++;
                UIATarget.localTarget().captureScreenWithName("" + step);
                UIATarget.localTarget().delay(0.15);
            }
        }
        else if (type == "play"){
            var all = stdout[1];
            var command = all.split(";");
            for (var i = 0; i < command.length ; i++){
                UIALogger.logMessage(""+command[i]);
                //过滤掉perform标记
                step++;
                UIATarget.localTarget().captureScreenWithName("" + step);
                //首先过滤掉perform字段
                if (command[i].indexOf("perform") > 0){
                    continue;
                }
                eval(command[i]);
                //如果是非delay操作，那么需要给出延迟截图操作
                if (command[i].indexOf("delay") <= 0 && command[i].length > 0){
                    
                    for (var j = 0;j < 3;j++){
                        step++;
                        UIATarget.localTarget().captureScreenWithName("" + step);
                        UIATarget.localTarget().delay(0.15);
                    }
                }	
            }
        }
    }
    
} catch (e) {
    
//    sendToServer = "Exception # " + e + ". The script is : " + "script";
//    UIALogger.logFail("The case was failed." + sendToServer);
}