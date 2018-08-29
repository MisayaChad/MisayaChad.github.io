---
title: Android录视频静音
date: 2017-08-23 20:30:19
categories: Android
---
Android录视频静音

解决录视频可以关闭/开启声音

``` java
private void setMicMuted(boolean state){
    AudioManager myAudioManager = (AudioManager)mContext.getSystemService(Context.AUDIO_SERVICE);

    // get the working mode and keep it
    int workingAudioMode = myAudioManager.getMode();

    myAudioManager.setMode(AudioManager.MODE_IN_COMMUNICATION);

    // change mic state only if needed
    if (myAudioManager.isMicrophoneMute() != state) {
        myAudioManager.setMicrophoneMute(state);
    }

    // set back the original working mode
    myAudioManager.setMode(workingAudioMode);
}
```

refrence: https://www.itstrike.cn/Question/ef401819-3f4c-42ce-b873-5e418f076faf.html
