# AUCapture

A packet capture app without remote VPN server. A demonstration for how to use `NEPacketTunnelProvider` and `NetworkExtension.framwork`.

## How to build

1. Open this xcodeproj with XCode, select `AUCapture` target, in `General > Identity` section, change `Bundle Identifier` to your Bundle ID.

1. Do the same thing for `PacketTunnel` target.

1. Change the App Group of both targets to yours.

[Presentation at iOSDC 2021](https://speakerdeck.com/kishikawakatsumi/network-extensiondeiosdebaisushang-dedong-kupaketutokiyaputiyawozuo-ru)

※スライドに使ったコードよりシンプルにしているので、UIやTCPのエミュレーションは省いています。もし同じものを試したい場合はIssueなどでリクエストしてください🙏🏻（整理しきれてない部分もあるのでリクエストがあればできるだけ急いでまとめます。）


If you can run it correctly, the Xcode console will look like the following.

<img width="800" alt="Screen Shot" src="https://user-images.githubusercontent.com/40610/133860072-496db787-9c7c-4f8d-a05b-9ca61da60193.png">
