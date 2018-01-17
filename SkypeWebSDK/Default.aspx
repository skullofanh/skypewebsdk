<%@ Page Language="vb" AutoEventWireup="false" CodeBehind="Default.aspx.vb" Inherits="SkypeWebSDK._Default" %>

<!DOCTYPE html>

<html xmlns="http://www.w3.org/1999/xhtml">
<head runat="server">
    <meta charset="utf-8" />
    <meta http-equiv="X-UA-Compatible" content="IE=edge" />
    <title>Skype Web SDK</title>
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <link rel="stylesheet" href="stylesheet/app.css" />
    <!--layout file-->
    <script src="Script/jquery.min.js"></script> <!-- 20180115 ANHLD ADD-->
    <script src="Script/config.js"></script> <!-- setting file-->
    <script src="https://swx.cdn.skype.com/shared/v/1.2.15/SkypeBootstrap.min.js"></script>
    <!--Skype Web SDK-->
</head>
<body>
    <form id="frmMain" runat="server">
        <div id="conversationWindow"></div>
    </form>
</body>

<script type="text/javascript">
    var apiManager = null;
    var client = null;
    var conversation = null;
    var windowConversation = document.getElementById("conversationWindow");
    var userName = "";

    config.clientid = "<%=Environment.GetEnvironmentVariable("APPSETTING_CLIENT_ID") %>";
    config.replyurl = '<%=Environment.GetEnvironmentVariable("REPLY_URL") %>';
    config.appName = '<%=Environment.GetEnvironmentVariable("APP_NAME") %>';
    config.mettingUrl = '<%=Environment.GetEnvironmentVariable("METTING_URL") %>';
    config.isMute = '<%=Environment.GetEnvironmentVariable("IS_MUTE") %>';

    /*
       Generate Conference URI.
    */
    function fnc_GetConferenceUri(strURl, userName) {
        var rs = strURl.replace('//', '/');
        var arr = rs.split('/')
        var result = "";

        if (arr.length == 5 && userName.split('@').length > 1) {
            result = "sip:" + arr[3] + "@" + userName.split('@')[1] + ";gruu;opaque=app:conf:focus:id:" + arr[4];
        }

        return result;
    }

    /*
    Join meeting
    */
    function fnc_joinMeeting() {
        try {
            //var uri = "sip:develop@heartis-sc.co.jp;gruu;opaque=app:conf:focus:id:6FPVZTVF
            var uri = fnc_GetConferenceUri(config.mettingUrl, userName);
            conversation = client.conversationsManager.getConversationByUri(uri);

            //Event-conversation.state.changed
            conversation.state.changed(function (newValue, reason, oldValue) {
                console.log("conversation.state.changed: " + newValue);
                if (newValue === 'Connected' || newValue == 'Conferenced') {
                }
                if (newValue === 'Disconnected' && (oldValue === 'Connected' || oldValue === 'Connecting' ||
                    oldValue === 'Conferenced' || oldValue === 'Conferencing')) {
                    // Call disconnected after being connected
                }

                if (newValue == 'Created') {

                    //Event handler : Get notified when conversation control receives an incoming call
                    conversation.selfParticipant.video.state.changed(function (newValue, reason, oldValue) {

                        // 'Notified' indicates that there is an incoming call
                        console.log("conversation.selfParticipant.video.state.changed_NEW:" + newValue);

                        if (newValue === 'Notified') {

                            conversation.videoService.accept();
                        }
                        else if (newValue === 'Connected') {
                            conversation.selfParticipant.audio.isMuted.set(config.isMute); //20180115 ANHLD ADD
                            var fullMode = $('#swxContent1').find('.fullscreenOn').parent();

                            if (fullMode && fullMode.attr('title') && fullMode.attr('title').indexOf('Enter') != -1) {
                                fullMode.click();
                            }
                        }
                    });

                    //===  Start video call
                    conversation.videoService.start().then(function () {
                        console.log("conversation.videoService.start()");
                        var input = conversation.selfParticipant.person.email();
                        var uris = input.split(',').map(function (s) { return s.trim(); });
                        var container = document.getElementById(input);

                        if (!container) {
                            container = document.createElement('div');
                            container.id = input;

                            windowConversation.appendChild(container);
                        }
                        //render Conversation Control in a web page.
                        var promise = apiManager.renderConversation(container, {
                            //Start outgoing call with chat window
                            conversation: conversation,
                            modalities: ['Audio', 'Video'],
                            participants: uris
                        });
                    }).then(function () {
                        var fullMode = $('#swxContent1').find('.fullscreenOn').parent();

                        if (fullMode && fullMode.attr('title') && fullMode.attr('title').indexOf('Enter') != -1) {
                            fullMode.click();
                        }
                    });
                    //===  Start video call

                    //Turn on Mic
                    //conversation.selfParticipant.audio.isMuted.set(true); //20180115 ANHLD DELETE
                }

            }, function (error) {
                // handle error
            });

            //Event-conversation.selfParticipant.state.changed
            conversation.selfParticipant.state.changed(function (newValue, reason, oldValue) {
                // 'Notified' indicates that there is an incoming call
                console.log("conversation.selfParticipant.state.changed:" + newValue);
            });

            //Event-conversation.participants.added
            conversation.participants.added(function (person) {
                console.log("conversation.participants.added:" + "=>" + person.displayName());

                //Event-person.state.changed
                person.state.changed(function (newValue, reason, oldValue) {
                    // 'Notified' indicates that there is an incoming call
                    console.log("person.state.changed:" + newValue);
                });
            });
        } catch (e) {
            console.log("fnc_joinMeeting:" + e.message);
        }
    }

    /*
    Init skype.
    */
    function fnc_InitSkype() {
        try {
            Skype.initialize({ apiKey: config.apiKeyCC }, function (api) {
                apiManager = api;
                client = apiManager.UIApplicationInstance;
                console.log("Skype Web SDK & Conversation Control Initialize success!");

                //Event handler: client.signInManager.state.changed
                client.signInManager.state.changed(function (state) {
                    console.log(state);
                });

                ////Login
                fnc_LoginSkype();

            });
        } catch (e) {
            console.log("fnc_InitSkype:" + e.message);
        }
    }

    /*
    Login skype.
    */
    function fnc_LoginSkype() {
        try {
            var params =
                {
                    "client_id": config.clientid,
                    "origins": [config.origins],
                    "cors": true,
                    "version": config.appName + '/1.0.0',
                    "redirect_uri": config.replyurl
                };

            //Event handler: client.signInManager.signIn
            client.signInManager.signIn(params).then(function () {
                userName = client.personsAndGroupsManager.mePerson.email();
                fnc_joinMeeting();
            });
        } catch (e) {
            console.log("fnc_LoginSkype:" + e.message);
        }
    }

    /*
    Reload page.
    */
    function fnc_Reload() {
        if (conversation != null) {
            conversation.leave();
        }
    }

    (function () {
        //Init skype
        //Retrieves access token from URL fragment

        if (location.hash) {
            var hasharr = location.hash.substr(1).split("&");
            hasharr.forEach(function (hashelem) {
                var elemarr = hashelem.split("=");
                if (elemarr[0] == "access_token") {
                    //console.log('Access Token: ' + elemarr[1]);

                    //Init skype
                    fnc_InitSkype();
                }
            }, this);
        }
        else {
            //Redirect to Login page
            location.assign(
                config.loginurl +
                '&client_id=' + config.clientid +
                '&resource=' + config.resource +
                '&redirect_uri=' + config.replyurl
            );
        }

        //Before refresh page
        window.onbeforeunload = function (event) {
            return fnc_Reload();
        };
    }());
    </script>

</html>
