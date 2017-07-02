//
//  FirstViewController.swift
//  MyLocations
//
//  Created by Silver Chu on 2017/6/15.
//  Copyright © 2017年 Silver Chu. All rights reserved.
//

import UIKit
import CoreLocation
import CoreData
import QuartzCore
import AudioToolbox

class CurrentLocationViewController: UIViewController, CLLocationManagerDelegate, CAAnimationDelegate {
    
    let locationManager = CLLocationManager()
    let geocoder = CLGeocoder() // 执行地理编码的对象
    
    var location: CLLocation? // 存储用户当前位置信息
    var updatingLocation = false // 判断是否正在获取位置信息
    var lastLocationError: Error?
    var placemark: CLPlacemark? // 包含Address信息的对象
    var performingReverseGeocoding = false // 判断是否正在执行逆向地理编码
    var lastGeocodingError: Error?
    var timer: Timer? // 定时器
    var managedObjectContext: NSManagedObjectContext!
    var logoVisible = false
    var soundID: SystemSoundID = 0
    
    lazy var logoButton: UIButton = {
        let button = UIButton(type: .custom)
        
        button.setBackgroundImage(UIImage(named: "Logo"), for: .normal)
        button.sizeToFit()
        button.addTarget(self, action: #selector(getLocation), for: .touchUpInside)
        button.center.x = self.view.bounds.midX
        button.center.y = 220
        
        return button
    }()

    @IBOutlet weak var messageLabel: UILabel!
    @IBOutlet weak var latitudeLabel: UILabel!
    @IBOutlet weak var longitudeLabel: UILabel!
    @IBOutlet weak var addressLabel: UILabel!
    @IBOutlet weak var tagButton: UIButton!
    @IBOutlet weak var getButton: UIButton!
    @IBOutlet weak var latitudeTextLabel: UILabel!
    @IBOutlet weak var longitudeTextLabel: UILabel!
    @IBOutlet weak var containerView: UIView!
    
    @IBAction func getLocation() {
        let authStatus = CLLocationManager.authorizationStatus() // 获取Location权限信息
        
        // 判断用户还未设置Location权限的情况
        if authStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
            return
        }
        
        // 判断用户禁止或者限制Location权限的情况
        if authStatus == .denied || authStatus == .restricted {
            showLocationServicesDeniedAlert() // 弹出提示框，提示用户在设置中打开Location权限
            return
        }
        
        if logoVisible {
            hideLogoView()
        }
        
        if updatingLocation {
            stopLocationManager()
        } else {
            // 重置数据
            location = nil
            lastLocationError = nil
            placemark = nil
            lastGeocodingError = nil
            startLocationManager()
        }
        updateLabels()
        configureGetButton()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        /** 初始化数据 **/
        updateLabels()
        configureGetButton()
        loadSoundEffect("Sound.caf")
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // Prepare-for-segue
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "TagLocation" {
            let navigationController = segue.destination as! UINavigationController
            let controller = navigationController.topViewController as! LocationDetailsViewController
            
            controller.coordinate = location!.coordinate
            controller.placemark = placemark
            controller.managedObjectContext = managedObjectContext
        }
    }

    // MARK: - CLLocationManagerDelegate
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("didFailWithError \(error)")
        
        if (error as NSError).code == CLError.locationUnknown.rawValue {
            return
        }
        
        lastLocationError = error // 获取错误信息，用作之后的错误处理
        
        stopLocationManager()
        updateLabels()
        configureGetButton()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let newLocation = locations.last! // 获取最新的Location数据
        print("didUpdateLocations \(newLocation)")
        print("\(newLocation.timestamp.timeIntervalSinceNow)")
        print("\(newLocation.horizontalAccuracy)")
        
        // 如果是之前的缓存数据，则跳出方法（限制为之前5秒以上）
        if newLocation.timestamp.timeIntervalSinceNow < -5 {
            return
        }
        
        // 忽略掉无效的测量数据
        if newLocation.horizontalAccuracy < 0 {
            return
        }
        
        // 用于衡量位置信息更新是否仍在改善
        var distance = CLLocationDistance(Double.greatestFiniteMagnitude) // DBL_MAX
        if let location = location {
            distance = newLocation.distance(from: location)
        }
        
        // 未收到用户location信息，也有已经收到location，用户再次获取location的情况，根据地址精度进行判断
        if location == nil || location!.horizontalAccuracy > newLocation.horizontalAccuracy {
            lastLocationError = nil // 设置nil主要为了清空之前的错误状态
            location = newLocation // 赋予location最新的地址信息
            updateLabels()
            
            // 最新地址精度比预设的精度（10m）高时，进行如下操作
            if newLocation.horizontalAccuracy <= locationManager.desiredAccuracy {
                print("*** We're done!")
                stopLocationManager()
                configureGetButton()
                
                // 强制根据最后一个位置信息做逆向地理编码
                if distance > 0 {
                    performingReverseGeocoding = false
                }
            }
            
            // 进行逆向地理编码
            if !performingReverseGeocoding {
                print("*** Going to geocode")
                
                performingReverseGeocoding = true
                
                geocoder.reverseGeocodeLocation(newLocation, completionHandler: { placemark, error in
                    print("*** Found placemarks: \(placemark), error: \(error)")
                    
                    self.lastGeocodingError = error // 传递错误信息，用作后续处理
                    
                    if error == nil, let p = placemark, !p.isEmpty {
                        if self.placemark == nil {
                            print("FIRST TIME!")
                            self.playSoundEffect()
                        }
                        
                        self.placemark = p.last! // 传递placemark信息
                    } else {
                        self.placemark = nil
                    }
                    
                    self.performingReverseGeocoding = false // 表示完成逆向地理编码，重置为false
                    self.updateLabels()
                })
            } else if distance < 1 { // distance不会绝对等于0，一般是一个接近0的小数
                let timeInterval = newLocation.timestamp.timeIntervalSince(location!.timestamp)
                
                // 间隔获取原始位置信息10秒以后强制结束，例如iPod持续重复获取+/- 100m时
                if timeInterval > 10 {
                    print("*** Force done!")
                    stopLocationManager()
                    updateLabels()
                    configureGetButton()
                }
            }
        }
    }
    
    func showLocationServicesDeniedAlert() {
        let alert = UIAlertController(title: "Location Services Disabled", message: "Please enable location services for this app in Settings.", preferredStyle: .alert)
        let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
        
        alert.addAction(okAction)
        
        present(alert, animated: true, completion: nil)
    }
    
    func updateLabels() {
        if let location = location {
            // 以小数点后8位的形式输出经纬度
            latitudeLabel.text = String(format: "%.8f", location.coordinate.latitude)
            longitudeLabel.text = String(format: "%.8f", location.coordinate.longitude)
            
            tagButton.isHidden = false // 当location中有用户当前地址信息时显示tagButton
            messageLabel.text = ""
            
            if let placemark = placemark {
                addressLabel.text = string(from: placemark) // 输出拼接的label
            } else if performingReverseGeocoding {
                addressLabel.text = "Searching for Address..."
            } else if lastGeocodingError != nil {
                addressLabel.text = "Error Finding Address"
            } else {
                addressLabel.text = "No Address Found"
            }
            
            latitudeTextLabel.isHidden = false
            longitudeTextLabel.isHidden = false
        } else {
            latitudeLabel.text = ""
            longitudeLabel.text = ""
            addressLabel.text = ""
            tagButton.isHidden = true
            
            let statusMessage: String
            
            // location = nil时的一些情况处理
            if let error = lastLocationError as? NSError {
                if error.domain == kCLErrorDomain && error.code == CLError.denied.rawValue {
                    statusMessage = "Location Services Disabled"
                } else {
                    statusMessage = "Error Getting Location"
                }
            } else if !CLLocationManager.locationServicesEnabled() {
                statusMessage = "Location Services Disabled"
            } else if updatingLocation {
                statusMessage = "Searching..."
            } else {
                statusMessage = ""
                showLogoView()
            }
            
            messageLabel.text = statusMessage
            
            latitudeTextLabel.isHidden = true
            longitudeTextLabel.isHidden = true
        }
    }
    
    func startLocationManager() {
        if CLLocationManager.locationServicesEnabled() {
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters // 预设精度
            
            locationManager.startUpdatingLocation()
            
            updatingLocation = true
            
            // 计时60秒后调用didTimeOut方法
            timer = Timer.scheduledTimer(timeInterval: 60, target: self, selector: #selector(didTimeOut), userInfo: nil, repeats: false)
        }
    }
    
    func stopLocationManager() {
        if updatingLocation {
            locationManager.stopUpdatingLocation()
            locationManager.delegate = nil
            updatingLocation = false
            
            if let timer = timer {
                timer.invalidate()
            }
        }
    }
    
    // 切换Button的内容
    func configureGetButton() {
        let spinnerTag = 1000
        
        if updatingLocation {
            getButton.setTitle("Stop", for: .normal)
            
            if view.viewWithTag(spinnerTag) == nil {
                let spinner = UIActivityIndicatorView(activityIndicatorStyle: .white)
                
                spinner.center = messageLabel.center
                spinner.center.y += (spinner.bounds.size.height / 2) + 15
                spinner.startAnimating()
                spinner.tag = spinnerTag
                containerView.addSubview(spinner)
            }
        } else {
            getButton.setTitle("Get My Location", for: .normal)
            
            if let spinner = view.viewWithTag(spinnerTag) {
                spinner.removeFromSuperview()
            }
        }
    }
    
    // 拼接placemark中的信息
    func string(from placemark: CLPlacemark) -> String {
        /*
        var line1 = ""
        
        // 子街道
        if let s = placemark.subThoroughfare {
            line1 += s + " "
        }
        
        // 街道
        if let s = placemark.thoroughfare {
            line1 += s
        }
        
        var line2 = ""
        
        // 地区
        if let s = placemark.locality {
            line2 += s + " "
        }
        
        // 行政区
        if let s = placemark.administrativeArea {
            line2 += s + " "
        }
        
        // 邮编
        if let s = placemark.postalCode {
            line2 += s
        }
        
        return line1 + "\n" + line2
        */
        var line1 = ""
        
        line1.add(text: placemark.subThoroughfare)
        line1.add(text: placemark.thoroughfare, separatedBy: " ")
        
        var line2 = ""
        
        line2.add(text: placemark.locality)
        line2.add(text: placemark.administrativeArea, separatedBy: " ")
        line2.add(text: placemark.postalCode, separatedBy: " ")
        
        line1.add(text: line2, separatedBy: "\n")
        
        return line1
    }
    
    func didTimeOut() {
        print("*** Time out")
        
        if location == nil {
            stopLocationManager()
            
            lastLocationError = NSError(domain: "MyLocationsErrorDomain", code: 1, userInfo: nil) // 超时添加相应的错误信息
            
            updateLabels()
            configureGetButton()
        }
    }
    
    // MARK: - Logo View
    func showLogoView() {
        if !logoVisible {
            logoVisible = true
            containerView.isHidden = true
            view.addSubview(logoButton)
        }
    }
    
    func hideLogoView() {
        if !logoVisible { return }
        
        logoVisible = false
        containerView.isHidden = false
        containerView.center.x = view.bounds.size.width * 2
        containerView.center.y = 40 + containerView.bounds.size.height / 2
        
        let centerX = view.bounds.midX
        let panelMover = CABasicAnimation(keyPath: "position")
        
        panelMover.isRemovedOnCompletion = false
        panelMover.fillMode = kCAFillModeForwards
        panelMover.duration = 0.6
        panelMover.fromValue = NSValue(cgPoint: containerView.center)
        panelMover.toValue = NSValue(cgPoint: CGPoint(x: centerX, y: containerView.center.y))
        panelMover.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseOut)
        panelMover.delegate = self
        containerView.layer.add(panelMover, forKey: "panelMover")
        
        let logoMover = CABasicAnimation(keyPath: "position")
        
        logoMover.isRemovedOnCompletion = false
        logoMover.fillMode = kCAFillModeForwards
        logoMover.duration = 0.5
        logoMover.fromValue = NSValue(cgPoint: logoButton.center)
        logoMover.toValue = NSValue(cgPoint: CGPoint(x: -centerX, y: logoButton.center.y))
        logoMover.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseIn)
        logoButton.layer.add(logoMover, forKey: "logoMover")
        
        let logoRotator = CABasicAnimation(keyPath: "transform.rotation.z")
        
        logoRotator.isRemovedOnCompletion = false
        logoRotator.fillMode = kCAFillModeForwards
        logoRotator.duration = 0.5
        logoRotator.fromValue = 0.0
        logoRotator.toValue = -2 * Double.pi
        logoRotator.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseIn)
        logoButton.layer.add(logoRotator, forKey: "logoRatator")
    }
    
    func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
        containerView.layer.removeAllAnimations()
        containerView.center.x = view.bounds.size.width / 2
        containerView.center.y = 40 + containerView.bounds.size.height / 2
        
        logoButton.layer.removeAllAnimations()
        logoButton.removeFromSuperview()
    }

    // MARK: - Sound Effect
    func loadSoundEffect(_ name: String) {
        if let path = Bundle.main.path(forResource: name, ofType: nil) {
            let fileURL = URL(fileURLWithPath: path, isDirectory: false)
            let error = AudioServicesCreateSystemSoundID(fileURL as CFURL, &soundID)
            
            if error != kAudioServicesNoError {
                print("Error code \(error) loading sound at path: \(path)")
            }
        }
    }
    
    func unloadSoundEffect() {
        AudioServicesDisposeSystemSoundID(soundID)
        soundID = 0
    }
    
    func playSoundEffect() {
        AudioServicesPlaySystemSound(soundID)
    }
    
}

