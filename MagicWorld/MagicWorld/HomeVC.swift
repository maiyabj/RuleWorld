//
//  HomeVC.swift
//  MagicWorld
//
//  Created by suyuexin on 2025/12/25.
//

import UIKit
import Flutter
import SnapKit
import Then

class HomeVC: UIViewController {

    private let backgroundImageView = UIImageView().then {
        $0.image = UIImage(named: "golden_apple")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        view.addSubview(backgroundImageView)
        backgroundImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        // 使用单引擎模式 + MethodChannel 调用
        let route = Bool.random() ? "/profile" : "/detail"
        openFlutterPage(route: route)
    }

    // 单引擎模式 + MethodChannel 调用方式
    // 优点：
    // 1. 复用单个 FlutterEngine，性能更好
    // 2. 通过 MethodChannel 通知 Flutter 端初始化页面
    // 3. 避免每次重启引擎的开销
    private func openFlutterPage(route: String) {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
            return
        }

        // 获取共享的 FlutterEngine
        let flutterEngine = appDelegate.getSharedFlutterEngine()

        // 创建 FlutterViewController
//        let hostingVC = FlutterViewController(
//            engine: flutterEngine,
//            nibName: nil,
//            bundle: nil
//        )
        
        let hostingVC = FlutterViewController(project: nil, initialRoute: route, nibName: nil, bundle: nil)

        // 添加启动页遮罩
        let backgroundImageView = UIImageView().then {
            $0.image = UIImage(named: "golden_apple")
        }
        backgroundImageView.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
        hostingVC.splashScreenView = backgroundImageView

        // 通过 MethodChannel 通知 Flutter 端要打开的页面
//        let channel = FlutterMethodChannel(
//            name: "com.magic.world/navigation",
//            binaryMessenger: flutterEngine.binaryMessenger
//        )
//
//        // 设置 MethodChannel 回调，监听 Flutter 端的返回请求
//        channel.setMethodCallHandler { [weak self] (call, result) in
//            if call.method == "popToNative" {
//                // Flutter 请求返回原生页面
//                DispatchQueue.main.async {
//                    self?.navigationController?.popViewController(animated: true)
//                }
//                result(nil)
//            } else {
//                result(FlutterMethodNotImplemented)
//            }
//        }
        // 推送到导航栈
        self.navigationController?.pushViewController(hostingVC, animated: true)
        
        // 在页面显示后通知 Flutter 端要打开的页面
//        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
//            channel.invokeMethod("navigateTo", arguments: [
//                "routeName": route,
//                "arguments": ["source": "native"]
//            ])
//        }
    }

}

