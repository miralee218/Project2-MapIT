//
//  AddLocationCViewController.swift
//  MapIT
//
//  Created by Mira on 2019/4/6.
//  Copyright © 2019 AppWork. All rights reserved.
//

import UIKit
import MapKit
import PullUpController
import CoreData
import PopupDialog
import SwiftMessages

class RecordListCViewController: PullUpController {

    @IBOutlet weak var tableView: UITableView! {
        didSet {

            tableView.dataSource = self

            tableView.delegate = self
        }
    }
    var initialPointOffset: CGFloat {

        return swipeView.frame.height + 70

    }
    @IBOutlet weak var firstPreviewView: UIView!
    @IBOutlet weak var secondPreviewView: UIView!
    @IBOutlet weak var swipeView: UIView! {
        didSet {
            swipeView.layer.cornerRadius = 15.0
        }
    }
    @IBOutlet weak var noDataView: UIView!
    @IBOutlet weak var searchSeparatorView: UIView! {
        didSet {
            searchSeparatorView.layer.cornerRadius = searchSeparatorView.frame.height/2
        }
    }

    public var portraitSize: CGSize = .zero
    public var landscapeFrame: CGRect = .zero

    var travel: Travel?
    var isEditting: Bool?
    lazy var locationPost = (travel?.locationPosts?.allObjects as? [LocationPost])
    var coordinate = CLLocationCoordinate2D()
    var deleteHandler: (() -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()

        portraitSize = CGSize(width: min(UIScreen.main.bounds.width, UIScreen.main.bounds.height),
                              height: secondPreviewView.frame.maxY)

        tableView.separatorStyle = .none

        tableView.mr_registerCellWithNib(identifier: String(describing: RouteTableViewCell.self), bundle: nil)

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(reloadRecordList),
                                               name: Notification.Name("reloadRecordList"),
                                               object: nil)
        if self.locationPost?.count == 0 {
            noDataView.isHidden = false
        } else {
            noDataView.isHidden = true
        }
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)
//        (isEditting, travel) = MapManager.checkEditStatusAndGetCurrentTravel()
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(true)
        NotificationCenter.default.removeObserver(self, name: .reloadRecordList, object: nil)
    }
    @objc func reloadRecordList() {
//        (isEditting, travel) = MapManager.checkEditStatusAndGetCurrentTravel()
        self.locationPost = travel?.locationPosts?.allObjects as? [LocationPost]
        if self.locationPost?.count == 0 {
            noDataView.isHidden = false
        } else {
            noDataView.isHidden = true
        }
        self.tableView.reloadData()
    }
    // MARK: - PullUpController
    override var pullUpControllerPreferredSize: CGSize {
        return portraitSize
    }

    override var pullUpControllerPreferredLandscapeFrame: CGRect {
        return landscapeFrame
    }

    override var pullUpControllerBounceOffset: CGFloat {
        return 10
    }

    override func pullUpControllerAnimate(action: PullUpController.Action,
                                          withDuration duration: TimeInterval,
                                          animations: @escaping () -> Void,
                                          completion: ((Bool) -> Void)?) {
        switch action {
        case .move:
            UIView.animate(withDuration: 0.3,
                           delay: 0,
                           usingSpringWithDamping: 0.7,
                           initialSpringVelocity: 0,
                           options: .curveEaseInOut,
                           animations: animations,
                           completion: completion)
            tableView.reloadData()
        default:
            UIView.animate(withDuration: 0.3,
                           animations: animations,
                           completion: completion)
        }
    }
}

extension RecordListCViewController: UITableViewDelegate, UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let locationPostCount = locationPost?.count else {
            return 0
        }
        return locationPostCount
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: String(describing: RouteTableViewCell.self),
            for: indexPath
        )
        guard let routeCell = cell as? RouteTableViewCell else { return cell }

        routeCell.actionBlock = { [weak self] in

            let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)

            let option3 = UIAlertAction(title: "編輯", style: .default) { [weak self] (_) in

                let vc = UIStoryboard.mapping.instantiateViewController(
                    withIdentifier: String(describing: EditLocationCViewController.self))

                guard let editVC = vc as? EditLocationCViewController else { return }

                editVC.saveHandler = {

                    self?.tableView.reloadData()
                }

                editVC.seletedPost = self?.locationPost?[indexPath.row]

                self?.present(editVC, animated: true, completion: nil)
            }

            let option2 = UIAlertAction(title: "刪除", style: .destructive) {[weak self] (_) in
                guard let strongSelf = self else { return }
                MiraDialog.showDeleteDialog(animated: true, deleteHandler: { [weak self] in
                    guard let removeOrder = self?.locationPost?[indexPath.row] else { return }
                    MiraMessage.deleteSuccessfully()
                    let fileManager = FileManager.default
                    let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
                    guard let totalPhoto = self?.locationPost?[indexPath.row].photo, totalPhoto.count <= 0 else {
//                        CoreDataManager.delete(removeOrder)
                        CoreDataManager.shared.delete(removeOrder)
                        self?.locationPost?.remove(at: indexPath.row)
                        tableView.deleteRows(at: [indexPath], with: .fade)
                        if self?.locationPost?.count == 0 {
                            self?.noDataView.isHidden = false
                        } else {
                            self?.noDataView.isHidden = true
                        }
                        NotificationCenter.default.post(name: .addAnnotations, object: nil)
                        tableView.reloadData()
                        return
                    }
                    for photo in 0...totalPhoto.count - 1 {
                        do {
                            try fileManager.removeItem(at: (documentsURL?.appendingPathComponent(totalPhoto[photo]))!)
                        } catch {
                        }
                    }
//                    CoreDataManager.delete(removeOrder)
                    CoreDataManager.shared.delete(removeOrder)
                    self?.locationPost?.remove(at: indexPath.row)
                    tableView.deleteRows(at: [indexPath], with: .fade)
                    tableView.reloadData()
                    }, vc: strongSelf)
            }

            let option1 = UIAlertAction(title: "取消", style: .cancel, handler: nil)
            sheet.addAction(option3)
            sheet.addAction(option2)
            sheet.addAction(option1)

            self?.present(sheet, animated: true, completion: nil)

        }

        guard let locationPost = self.locationPost else {
            return cell
        }
        let sortedLocationPost = sortResults(items: locationPost)
        self.locationPost = sortedLocationPost
        if locationPost[indexPath.row].photo?.count == nil {
            routeCell.collectionView.isHidden = true
        }
        routeCell.pointTitleLabel.text = locationPost[indexPath.row].title
        routeCell.pointDescriptionLabel.text = locationPost[indexPath.row].content
        guard let currentLocationPost = self.locationPost?[indexPath.row] else {
            return cell
        }
        routeCell.locationPost = currentLocationPost
        let formattedDate = FormatDisplay.postDate(locationPost[indexPath.row].timestamp)
        routeCell.pointRecordTimeLabel.text = formattedDate
        return routeCell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {

        guard locationPost?[indexPath.row].photo?.count != nil else {
            return 100
        }
        return 195
    }
    func sortResults(items: [LocationPost]) -> [LocationPost] {
        var sortResults: [LocationPost] = []
        if let sortedArray = (items as NSArray).sortedArray(using: [
            NSSortDescriptor(key: "timestamp", ascending: true)]) as? [LocationPost] {
            sortResults = sortedArray
        }
        return sortResults
    }

}
