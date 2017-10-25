---
title: Umeng消息的完全自定义处理
date: 2017-09-04 14:23:16
categories: Android
---
1，下面的前提是必须申请了友盟且有app key
2，集成友盟SDK  参看官方文档http://dev.umeng.com/push/android/integration#1
3，若开发者需要实现对消息的完全自定义处理，则可以继承 UmengBaseIntentService, 实现自己的Service来完全控制达到消息的处理。
    1,实现一个类，继承 UmengBaseIntentService， 重写onMessage(Context context, Intent intent) 方法，并请调用super.onMessage(context, intent)。参考 demo 应用中MyPushIntentService。请参考下面代码：
```    
/**
 * 友盟推送服务
 */
public class PushIntentService extends UmengBaseIntentService {
    private static final String TAG = PushIntentService.class.getName();

// 如果需要打开Activity，请调用Intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)；否则无法打开Activity。

    @Override
    protected void onMessage(Context context, Intent intent) {
        // 需要调用父类的函数，否则无法统计到消息送达
        super.onMessage(context, intent);
        try {
            //可以通过MESSAGE_BODY取得消息体
            String message = intent.getStringExtra(BaseConstants.MESSAGE_BODY);
//            String str=message.replaceAll("\\\\", "");//将URL中的反斜杠替换为空  加上之后收不到消息
            UMessage msg = new UMessage(new JSONObject(message));
            Log.d(TAG,"message=" + message);    //消息体
            Log.d(TAG, "custom=" + msg.custom);    //自定义消息的内容
            Log.d(TAG, "title=" + msg.title);    //通知标题
            Log.d(TAG, "text=" + msg.text);    //通知内容
            //消息处理
            Map<String ,String> extra=msg.extra;
            String displayType=extra.get("displayType");//展示情况WAP 和直接activity展示
            Intent intentAct = new Intent();
            intentAct.setClass(context, MessageDetailActivity.class);
            intentAct.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            Bundle bundle = new Bundle();
            MessageItem item=new MessageItem();//自定义的消息bean
            item.setMsmType("PUSH");
            item.setMsmcontent(msg.text);//获取推送的消息内容
            item.setTitle(msg.title);//获取推送的消息标题
            if (displayType.equals("DISPLAYONAPP")){//手机端展示
                item.setDisplayType("DISPLAYONAPP");
            } else if (displayType.equals("DISPLAYONWAP")){//打开指定网页
                item.setDisplayType("DISPLAYONWAP");
                item.setOtherParams(extra.get("otherParams"));//将整个自定义参数传出去，在需要的地方处理
            }else{
                System.out.println("推送消息类型错误！");
            }
            bundle.putSerializable("message", item);//传递一个序列化参数
            intentAct.putExtras(bundle);
            showNotification(context, msg, intentAct);//必须要有，不然收不到推送的消息
            // 完全自定义消息的处理方式，点击或者忽略
            boolean isClickOrDismissed = true;
            if(isClickOrDismissed) {
                //完全自定义消息的点击统计
                UTrack.getInstance(getApplicationContext()).trackMsgClick(msg);
            } else {
                //完全自定义消息的忽略统计
                UTrack.getInstance(getApplicationContext()).trackMsgDismissed(msg);
            }
        } catch (Exception e) {
            Log.e(TAG, e.getMessage());
        }
    }
    // 通知栏显示当前播放信息，利用通知和 PendingIntent来启动对应的activity
    public void showNotification(Context context,UMessage msg,Intent intent) {
        NotificationManager mNotificationManager = (NotificationManager) getSystemService(NOTIFICATION_SERVICE);
        NotificationCompat.Builder builder = new NotificationCompat.Builder(context);
        builder.setAutoCancel(true);
        Notification mNotification = builder.build();
        mNotification.icon = R.drawable.ic_launcher;//notification通知栏图标
        mNotification.defaults |= Notification.DEFAULT_SOUND;
        mNotification.defaults |= Notification.DEFAULT_VIBRATE ;
        mNotification.tickerText=msg.ticker;
        //自定义布局
        RemoteViews contentView = new RemoteViews(getPackageName(), R.layout.activity_umeng_push);
        contentView.setImageViewResource(R.id.Umeng_view, R.drawable.ic_launcher);
        contentView.setTextViewText(R.id.push_title, msg.title);
        contentView.setTextViewText(R.id.push_content, msg.text);
        mNotification.contentView = contentView;
        PendingIntent contentIntent = PendingIntent.getActivity(context, 0,
                intent, PendingIntent.FLAG_UPDATE_CURRENT);//不是Intent
        //notifcation.flags = Notification.FLAG_NO_CLEAR;// 永久在通知栏里
        mNotification.flags = Notification.FLAG_AUTO_CANCEL;
        //使用自定义下拉视图时，不需要再调用setLatestEventInfo()方法，但是必须定义contentIntent
        mNotification.contentIntent = contentIntent;

        mNotificationManager.notify(103, mNotification);
    }
}
说明：当自定义的参数中有URL时，会被转义，不要在这里面处理，把整个参数传递出去，在需要的地方进行取缔，不然会收不到推送的消息，我的message如下：
   message={
    "msg_id":"uu56667143874445555800",
    "display_type":"notification",
    "alias":"",
    "random_min":0,
    "body":{
        "text":"content",
        "title":"title",
        "ticker":"ticker",
        "play_vibrate":"true",
        "play_lights":"true",
        "play_sound":"true"
    },
    "extra":{
        "otherParams":"
            {\"url\":\"http://www.baidu.com\"}",
            "displayType":"DISPLAYONWAP"
            }
        }
自定义的messageItem如下：
package com.pitaya.daokoudai.model.bean.account;

import org.json.JSONException;
import org.json.JSONObject;

import Java.io.Serializable;

/**
 * 我的消息  bean  包含類型，時間，類容，狀態,消息未读数
 */
public class MessageItem implements Serializable {
    private String msmType;
    private Long msmDate;
    private String msmcontent;
    private boolean msmstatus;
    private int unreadmsg;
    private Long id;
    private String displayType;
    private String otherParams;

    public String getDisplayType() {
        return displayType;
    }

    public void setDisplayType(String displayType) {
        this.displayType = displayType;
    }

    public String getOtherParams() {
        return otherParams;
    }

    public void setOtherParams(String otherParams) {//将参数中的\全部换成“”
        String string=otherParams.replaceAll("\\\\","");//是4杠，不是2杠
        try {
            JSONObject jsonObject=new JSONObject(string);
            this.otherParams = jsonObject.optString("url");
        } catch (JSONException e) {
            e.printStackTrace();
        }

    }

    public String getTitle() {
        return title;
    }

    public void setTitle(String title) {
        this.title = title;
    }

    private String title;

    public int getUnreadmsg() {
        return unreadmsg;
    }

    public void setUnreadmsg(int unreadmsg) {
        this.unreadmsg = unreadmsg;
    }

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public String getMsmType() {
        return msmType;
    }

    public void setMsmType(String msmType) {
        this.msmType = msmType;
    }

    public Long getMsmDate() {
        return msmDate;
    }

    public void setMsmDate(Long msmDate) {
        this.msmDate = msmDate;
    }

    public String getMsmcontent() {
        return msmcontent;
    }

    public void setMsmcontent(String msmcontent) {
        this.msmcontent = msmcontent;
    }

    public boolean getMsmstatus() {
        return msmstatus;
    }

    public void setMsmstatus(boolean msmstatus) {
        this.msmstatus = msmstatus;
    }
}


    2,在AndroidManifest.xml 中声明。

    <!-- 请填写实际的类名，下面仅是示例代码-->
    <service android:name="com.umeng.message.example.MyPushIntentService" android:process=":push"/>

    3,在主Activity中调用。

    /**推送开启 **/
    PushAgent mPushAgent = PushAgent.getInstance(this);
    mPushAgent.enable();//开启推送
    mPushAgent.setDebugMode(true);
    mPushAgent.setPushIntentServiceClass(PushIntentService.class)
```
