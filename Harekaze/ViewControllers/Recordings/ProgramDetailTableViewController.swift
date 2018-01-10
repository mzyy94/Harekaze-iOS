/**
 *
 * ProgramDetailTableViewController.swift
 * Harekaze
 * Created by Yuki MIZUNO on 2016/07/12.
 * 
 * Copyright (c) 2016-2018, Yuki MIZUNO
 * All rights reserved.
 * 
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 * 
 * 1. Redistributions of source code must retain the above copyright notice,
 *    this list of conditions and the following disclaimer.
 * 
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 *    this list of conditions and the following disclaimer in the documentation
 *     and/or other materials provided with the distribution.
 * 
 * 3. Neither the name of the copyright holder nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 * 
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
 * THE POSSIBILITY OF SUCH DAMAGE.
 */

import UIKit
import Kingfisher
import APIKit
import RealmSwift
import Crashlytics
import Alamofire
import CoreSpotlight
import MobileCoreServices
import Hero
import FileKit
import KOAlertController

class ProgramDetailTableViewController: UITableViewController, UIGestureRecognizerDelegate {

	// MARK: - Instance fileds
	var program: Program! = nil

	// MARK: - Private instance fileds
	private var download: Download! = nil
	private var dataSource: [[String: (Program) -> String]] = []

	// MARK: - IBOutlets
	@IBOutlet weak var headerView: UIView!
	@IBOutlet weak var titleLabel: UILabel!
	@IBOutlet weak var dateLabel: UILabel!
	@IBOutlet weak var channelLogoImage: UIImageView!
	@IBOutlet weak var thumbnailCollectionView: UICollectionView!
	@IBOutlet weak var playButton: UIButton!
	@IBOutlet weak var moreButton: UIButton!

	// MARK: - View initialization

	override func viewDidLoad() {
		let config = Realm.configuration(class: Download.self)
		let realm = try! Realm(configuration: config)

		// Add downloaded program to realm
		let predicate = NSPredicate(format: "id == %@", program.id)
		download = realm.objects(Download.self).filter(predicate).first

		super.viewDidLoad()
		self.extendedLayoutIncludesOpaqueBars = false
		self.navigationItem.largeTitleDisplayMode = .never
		self.navigationController?.interactivePopGestureRecognizer?.delegate = self

		self.tableView.tableHeaderView = headerView

		setChannelLogo()

		// Header Label
		self.titleLabel.text = program.title
		self.dateLabel.text = "\(program.startTime.string()) (\(program.duration.in(.minute)!)min)"
		self.titleLabel.preferredMaxLayoutWidth = 50
		self.titleLabel.numberOfLines = 0

		self.tableView.reloadData()

		// Setup table view data source
		dataSource.append(["Description": { program in program.detail != "" ? program.detail : " "}])
		dataSource.append(["Genre": { program in program.genre.capitalized}])
		dataSource.append(["Date": { program in program.startTime.string()}])
		if program.episode > 0 {
			dataSource.append(["Episode": { program in "Ep \(program.episode)"}])
		}
		dataSource.append(["Channel": { program in "\(program.channel!.name) [\(program.channel!.channel)]"}])
		dataSource.append(["Duration": { program in "\(program.duration.in(.minute)!) min."}])
		dataSource.append(["ID": { program in program.id.uppercased()}])
		if program.filePath.isEmpty {
			// Should be timer program
			self.headerView.frame.size.height -= self.thumbnailCollectionView.frame.height
			self.thumbnailCollectionView.isHidden = true
			self.playButton.isHidden = true
			return
		}
		dataSource.append(["Tuner": { program in program.tuner}])
		// FIXME: Auto resizing overflow text
//		dataSource.append(["Title": { program in program.fullTitle}])
//		dataSource.append(["File": { program in program.filePath}])
//		dataSource.append(["Command": { program in program.command}])

	}

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)

		// Swap Navigation bar color
		let tintColor = self.navigationController?.navigationBar.barTintColor
		self.navigationController?.navigationBar.barTintColor = self.navigationController?.navigationBar.tintColor
		self.navigationController?.navigationBar.tintColor = tintColor

		// Set navigation bar transparent background
		self.navigationController?.navigationBar.shadowImage = UIImage()
	}

	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		self.view.backgroundColor = UIColor.white
	}

	// FIXME: statusbar color
	override var preferredStatusBarStyle: UIStatusBarStyle {
		return .default
	}

	// MARK: - Channel logo setter
	func setChannelLogo() {
		do {
			let request = ChinachuAPI.ChannelLogoImageRequest(id: program.channel!.id)
			let urlRequest = try request.buildURLRequest()

			// Place holder image
			let rect = CGRect(x: 0, y: 0, width: channelLogoImage.frame.size.width, height: channelLogoImage.frame.size.height)
			UIGraphicsBeginImageContextWithOptions(channelLogoImage.frame.size, false, 0)
			UIColor.lightGray.setFill()
			UIRectFill(rect)
			let placeholderImage: UIImage = UIGraphicsGetImageFromCurrentImageContext()!
			UIGraphicsEndImageContext()

			self.channelLogoImage.kf.setImage(with: urlRequest.url!,
											  placeholder: placeholderImage,
											  options: [.transition(ImageTransition.fade(0.3)),
														.forceTransition,
														.requestModifier(AnyModifier(modify: { request in
															var request = request
															request.setValue(urlRequest.allHTTPHeaderFields?["Authorization"], forHTTPHeaderField: "Authorization")
															return request
														}
														))],
											  progressBlock: { _, _ in
			},
											  completionHandler: {(image, error, _, _) -> Void in
			})
		} catch let error {
			Answers.logCustomEvent(withName: "Channel logo load error", customAttributes: ["error": error, "file": #file, "function": #function, "line": #line])
		}
	}

	// MARK: - IBAction

	@IBAction func touchPlayButton() {
		showVideoPlayerView()
	}

	@IBAction func touchMoreButton() {
		let confirmDialog = KOAlertController("More...")
		confirmDialog.addAction(KOAlertButton(.default, title: "Share")) {
			// TODO: Show share sheet
		}
		if !program.filePath.isEmpty { // Should be recording program
			confirmDialog.addAction(KOAlertButton(.default, title: "Delete")) {
				self.confirmDeleteProgram()
			}
			if download == nil || DownloadManager.shared.progressRequest(download.id) == nil {
				confirmDialog.addAction(KOAlertButton(.default, title: "Download")) {
					self.startDownloadVideo()
				}
			} else {
				confirmDialog.addAction(KOAlertButton(.default, title: "Delete Downloaded")) {
					self.confirmDeleteDownloaded()
				}
			}
		}
		confirmDialog.addAction(KOAlertButton(.cancel, title: "Cancel")) {}
		self.navigationController?.parent?.present(confirmDialog, animated: false, completion: nil)
	}

	// MARK: - Event handler

	func confirmDeleteProgram() {
		let confirmDialog = KOAlertController("Delete program?", "Are you sure you want to permanently delete the program \(self.program.fullTitle) immediately?")
		confirmDialog.addAction(KOAlertButton(.default, title: "DELETE")) {
			confirmDialog.dismiss(animated: true, completion: nil)
			UIApplication.shared.isNetworkActivityIndicatorVisible = true
			let request = ChinachuAPI.DeleteProgramRequest(id: self.program.id)
			Session.send(request) { result in
				UIApplication.shared.isNetworkActivityIndicatorVisible = false
				switch result {
				case .success:
					let realm = try! Realm()
					try! realm.write {
						realm.delete(self.program)
					}
					_ = self.navigationController?.popViewController(animated: true)
				case .failure(let error):
					let dialog = MaterialAlertViewController.generateSimpleDialog("Delete program failed", message: ChinachuAPI.parseErrorMessage(error))
					self.present(dialog, animated: true, completion: nil)
				}
			}
		}
		confirmDialog.addAction(KOAlertButton(.cancel, title: "Cancel")) {}
		self.navigationController?.parent?.present(confirmDialog, animated: false, completion: nil)
	}

	func showVideoPlayerView() {
		guard let videoPlayViewController = self.storyboard!.instantiateViewController(withIdentifier: "VideoPlayerViewController") as?
			VideoPlayerViewController else {
			return
		}
		videoPlayViewController.program = program
		videoPlayViewController.transitioningDelegate = self as? UIViewControllerTransitioningDelegate
		self.present(videoPlayViewController, animated: true, completion: nil)
	}

	// MARK: - Program download

	func startDownloadVideo() {
		do {
			// Define local store file path
			let saveDirectoryPath = Path.userDocuments + program.id
			if !saveDirectoryPath.exists {
				try saveDirectoryPath.createDirectory()
			} else if !saveDirectoryPath.isDirectory {
				Answers.logCustomEvent(withName: "Create directory failed", customAttributes: ["path": saveDirectoryPath])
				return
			}
			let filepath = saveDirectoryPath + "file.m2ts"

			// Add downloaded program to realm
			let config = Realm.configuration(class: Download.self)
			let realm = try Realm(configuration: config)
			let download = Download()
			try realm.write {
				download.id = program!.id
				download.program = realm.create(Program.self, value: self.program, update: true)
				realm.add(download, update: true)
			}

			// Download request
			let request = ChinachuAPI.StreamingMediaRequest(id: program.id)
			let urlRequest: URLRequestConvertible = try request.buildURLRequest()
			let manager = DownloadManager.shared.createManager(program.id) {
				try! realm.write {
					download.size = filepath.attributes[FileAttributeKey.size] as? Int ?? 0
				}
				Answers.logCustomEvent(withName: "File download info", customAttributes: [
					"file size": download.size,
					"transcode": ChinachuAPI.Config[.transcode] && ChinachuAPI.Config[.transcode]
					])
			}
			let downloadRequest = manager.download(urlRequest) { (_, _) in
				return (filepath.url, [])
				}
				.response { response in
					if let error = response.error {
						Answers.logCustomEvent(withName: "Download file failed",
							customAttributes: ["error": error, "path": filepath, "request": response.request as Any, "response": response.response as Any])
					} else {
						try! realm.write {
							download.size = filepath.attributes[FileAttributeKey.size] as? Int ?? 0
						}
						Answers.logCustomEvent(withName: "File download info", customAttributes: [
							"file size": download.size,
							"transcode": ChinachuAPI.Config[.transcode]
							])
					}
			}
			// Show dialog
			let dialog = MaterialAlertViewController.generateSimpleDialog("The download has started", message: "Download progress is available at Download page.")
			self.navigationController?.present(dialog, animated: true, completion: nil)

			// Save request
			DownloadManager.shared.addRequest(program.id, request: downloadRequest)
		} catch let error as NSError {
			// Show dialog
			let dialog = MaterialAlertViewController.generateSimpleDialog("Download failed", message: error.localizedDescription)
			self.navigationController?.present(dialog, animated: true, completion: nil)
			Answers.logCustomEvent(withName: "File download error", customAttributes: ["error": error])
		}
	}

	func confirmDeleteDownloaded() {
		let confirmDialog = MaterialAlertViewController(title: "Delete downloaded program?",
		                                                message: "Are you sure you want to delete downloaded program \(program!.fullTitle)?",
														preferredStyle: .alert)
		let deleteAction = MaterialAlertAction(title: "DELETE", style: .destructive, handler: {_ in
			confirmDialog.dismiss(animated: true, completion: nil)

			let filepath = Path.userDocuments + self.download.program!.id + "file.m2ts"

			do {
				try filepath.deleteFile()

				// Delete downloaded program from realm
				let config = Realm.configuration(class: Download.self)
				let realm = try! Realm(configuration: config)
				try! realm.write {
					realm.delete(self.download)
				}
				_ = self.navigationController?.popViewController(animated: true)
			} catch let error as NSError {
				Answers.logCustomEvent(withName: "Delete downloaded program error", customAttributes: ["error": error])

				let dialog = MaterialAlertViewController.generateSimpleDialog("Delete downloaded program failed", message: error.localizedDescription)
				self.navigationController?.present(dialog, animated: true, completion: nil)
			}
		})
		let cancelAction = MaterialAlertAction(title: "CANCEL", style: .cancel, handler: {_ in
			confirmDialog.dismiss(animated: true, completion: nil)
		})
		confirmDialog.addAction(cancelAction)
		confirmDialog.addAction(deleteAction)

		self.navigationController?.present(confirmDialog, animated: true, completion: nil)
	}

	// MARK: - View deinitialization

	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)

		// Swap Navigation bar color
		// FIXME: animating color
		let tintColor = self.navigationController?.navigationBar.barTintColor
		self.navigationController?.navigationBar.barTintColor = self.navigationController?.navigationBar.tintColor
		self.navigationController?.navigationBar.tintColor = tintColor
	}

	deinit {
		NotificationCenter.default.removeObserver(self)
	}

	// MARK: - View layout

	override func viewWillLayoutSubviews() {
		super.viewWillLayoutSubviews()
	}

	// MARK: - Table view data source

	override func tableView(_ tableView: UITableView, estimatedHeightForHeaderInSection section: Int) -> CGFloat {
		return 100
	}

	override func numberOfSections(in tableView: UITableView) -> Int {
		return 1
	}

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return dataSource.count
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let data = dataSource[(indexPath as NSIndexPath).row].first!
		if indexPath.row == 0 {
			let cell = tableView.dequeueReusableCell(withIdentifier: "DescriptionCell", for: indexPath)
			cell.textLabel?.text = data.1(program)
			return cell
		} else {
			let cell = tableView.dequeueReusableCell(withIdentifier: "ItemCell", for: indexPath)
			cell.textLabel?.text = data.0
			cell.detailTextLabel?.text = data.1(program)
			return cell
		}
	}
}

extension ProgramDetailTableViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
	func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
		return 5
	}

	func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
		let width = self.view.frame.width * 0.88
		let height = width / 16 * 9
		return CGSize(width: width, height: height)
	}

	func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
		return self.view.frame.width * 0.12
	}

	func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
		return UIEdgeInsets(top: 0, left: self.view.frame.width * 0.06, bottom: 0, right: self.view.frame.width * 0.06)
	}

	func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
		let thumbnailCell = collectionView.dequeueReusableCell(withReuseIdentifier: "thumbnailCell", for: indexPath)
		let imageView = thumbnailCell.viewWithTag(2) as? UIImageView

		do {
			let segment = program.duration.in(.second)! / self.collectionView(self.thumbnailCollectionView, numberOfItemsInSection: indexPath.section)
			let request = ChinachuAPI.PreviewImageRequest(id: program.id, position: segment * indexPath.row + segment)
			let urlRequest = try request.buildURLRequest()

			// Place holder image
			let rect = CGRect(x: 0, y: 0, width: 1, height: 1)
			UIGraphicsBeginImageContextWithOptions(rect.size, false, 0)
			UIColor.lightGray.setFill()
			UIRectFill(rect)
			let placeholderImage: UIImage = UIGraphicsGetImageFromCurrentImageContext()!
			UIGraphicsEndImageContext()

			// Loading
			imageView?.kf.setImage(with: urlRequest.url!,
								  placeholder: placeholderImage,
								  options: [.transition(ImageTransition.fade(0.3)),
											.forceTransition,
											.requestModifier(AnyModifier(modify: { request in
												var request = request
												request.setValue(urlRequest.allHTTPHeaderFields?["Authorization"], forHTTPHeaderField: "Authorization")
												return request
											}
											))],
								  progressBlock: { _, _ in
			},
								  completionHandler: {(image, error, _, _) -> Void in
									if indexPath.row != 0 {
										return
									}
									guard let image = image else {
										return
									}
									let attributeSet = CSSearchableItemAttributeSet(itemContentType: kUTTypeItem as String)
									attributeSet.title = self.program.title
									attributeSet.contentDescription = self.program.detail
									attributeSet.addedDate = self.program.startTime
									attributeSet.duration = self.program.duration as NSNumber?
									attributeSet.thumbnailData = UIImageJPEGRepresentation(image, 0.3)
									let item = CSSearchableItem(uniqueIdentifier: self.program.id, domainIdentifier: "recordings", attributeSet: attributeSet)
									CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: [self.program.id], completionHandler: { error in
										if error != nil {
											return
										}
										CSSearchableIndex.default().indexSearchableItems([item], completionHandler: nil)
									})
			})

		} catch let error as NSError {
			Answers.logCustomEvent(withName: "Thumbnail load error", customAttributes: ["error": error, "file": #file, "function": #function, "line": #line])
		}
		return thumbnailCell
	}
}
