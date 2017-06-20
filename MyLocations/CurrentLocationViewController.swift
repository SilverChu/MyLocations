//
//  FirstViewController.swift
//  MyLocations
//
//  Created by Silver Chu on 2017/6/15.
//  Copyright © 2017年 Silver Chu. All rights reserved.
//

import UIKit
import CoreLocation

class CurrentLocationViewController: UIViewController, CLLocationManagerDelegate {
    
    let locationManager = CLLocationManager()
    let geocoder = CLGeocoder() // 执行地理编码的对象
    
    var location: CLLocation? // 存储用户当前位置信息
    var updatingLocation = false // 判断是否正在获取位置信息
    var lastLocationError: Error?
    var placemark: CLPlacemark? // 包含Address信息的对象
    var performingReverseGeocoding = false // 判断是否正在执行逆向地理编码
    var lastGeocodingError: Error?
    var timer: Timer? // 定时器

    @IBOutlet weak var messageLabel: UILabel!
    @IBOutlet weak var latitudeLabel: UILabel!
    @IBOutlet weak var longitudeLabel: UILabel!
    @IBOutlet weak var addressLabel: UILabel!
    @IBOutlet weak var tagButton: UIButton!
    @IBOutlet weak var getButton: UIButton!
    
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
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
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
        var distance = CLLocationDistance(DBL_MAX)
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
                statusMessage = "Tap 'Get My Location' to Start"
            }
            
            messageLabel.text = statusMessage
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
        if updatingLocation {
            getButton.setTitle("Stop", for: .normal)
        } else {
            getButton.setTitle("Get My Location", for: .normal)
        }
    }
    
    // 拼接placemark中的信息
    func string(from placemark: CLPlacemark) -> String {
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

}

