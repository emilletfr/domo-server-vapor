//
//  RollerShutterService.swift
//  VaporApp
//
//  Created by Eric on 14/12/2016.
//
//

import RxSwift

final class RollerShutterService : RollerShutterServicable
{
    let currentPositionObserver = [PublishSubject<Int>(), PublishSubject<Int>(), PublishSubject<Int>(), PublishSubject<Int>(), PublishSubject<Int>()]
    let targetPositionObserver = [PublishSubject<Int>(), PublishSubject<Int>(), PublishSubject<Int>(), PublishSubject<Int>(), PublishSubject<Int>()]
    
    let targetPositionPublisher = [PublishSubject<Int>(), PublishSubject<Int>(), PublishSubject<Int>(), PublishSubject<Int>(), PublishSubject<Int>()]
    
    let httpClient : HttpClientable
    
    required init(httpClient : HttpClientable = HttpClient()) {
        self.httpClient = httpClient
        self.reduce()
    }
    
    func reduce() {
        let action = PublishSubject<(Int, Int)>()
        // create actions
        for placeIndex in 0..<RollerShutter.count.rawValue {
            _ = targetPositionPublisher[placeIndex].distinctUntilChanged()
                .debounce(1, scheduler: ConcurrentDispatchQueueScheduler(qos: .default))
                .subscribe(onNext: { target in
                    self.targetPositionObserver[placeIndex].onNext(target)
                    action.onNext((placeIndex, target))
                })
        }
        // concat actions
        let queue = action.concatMap { (index:Int, target:Int) -> Observable<(Int, Int)> in
            var current = 100 - target
            _ = self.currentPositionObserver[index].subscribe(onNext: { c in
                current = c
            })
            return Observable.combineLatest(Observable.of(index), Observable.of(target))
                .flatMap({ (index:Int, target:Int) -> Observable<Int> in
                    return self.process(index, current, target) })
                .map({ target -> (Int, Int) in return (index, target)})
                .take(1)
        }
        // action completion subscription
        _ = queue.subscribe(onNext: { (index:Int, target:Int) in
            self.currentPositionObserver[index].onNext(target)
            self.targetPositionObserver[index].onNext(target)
        })
        // Wrap to Initial State
        for placeIndex in 0..<RollerShutter.count.rawValue {
            _ = self.httpClient.send(url: RollerShutter(rawValue: placeIndex)!.baseUrl(appendPath: "status"), responseType: RollerShutter.Response.self)
                .map({ (r) -> Int in return r.open*100 })
                .subscribe(onNext: { (position) in
                    self.currentPositionObserver[placeIndex].onNext(position)
                    self.targetPositionObserver[placeIndex].onNext(position)
                })
        }
    }
    
    func process(_ placeIndex:Int, _ currentPosition:Int, _ targetPosition:Int) -> Observable<Int>  {
        if currentPosition == targetPosition {
            return Observable.of(targetPosition)
        }
        let open = targetPosition > currentPosition ? "1" : "0"
        let urlString = RollerShutter(rawValue: placeIndex)!.baseUrl(appendPath: open)
        let offset = currentPosition > targetPosition ? currentPosition - targetPosition : targetPosition - currentPosition
        var delay : Int = Int(offset*14/100)
        if targetPosition == 0 || targetPosition == 100 {delay = 14}
        
        return self.httpClient.send(url: urlString, responseType: RollerShutter.Response.self)
            .flatMap({ _ in return secondEmitter }).skip(delay).take(1)
            .flatMap({_ in return self.httpClient.send(url: urlString, responseType: RollerShutter.Response.self)})
            .flatMap({ _ in return secondEmitter }).skip(1).take(1)
            .map({ _ in return targetPosition})
    }
}

enum RollerShutter: Int
{
    case livingRoom = 0, diningRoom, office, kitchen, bedroom, count
    
    func baseUrl(appendPath pathComponent: String = "") -> String {
        let scheme = "http://"
        var base = ""
        switch self {
        case .livingRoom: base = isHomeKitModulesNetworkIpOrDns
            ?  "192.168.8.50" : "living-room.local"
        case .diningRoom: base = isHomeKitModulesNetworkIpOrDns
            ?  "192.168.8.51" : "dining-room.local"
        case .office: base = isHomeKitModulesNetworkIpOrDns
            ?  "192.168.8.52" : "office.local"
        case .kitchen: base = isHomeKitModulesNetworkIpOrDns
            ?  "192.168.8.53" : "kitchen.local"
        case .bedroom: base = isHomeKitModulesNetworkIpOrDns
            ?  "192.168.8.54" : "bedroom.local"
        case .count: base = ""
        }
        return scheme + base + "/" + pathComponent
    }
    
    struct Response: Decodable
    {
        let open: Int
    }
}

