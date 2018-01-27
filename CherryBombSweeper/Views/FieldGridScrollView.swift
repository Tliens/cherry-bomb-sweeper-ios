//
//  FieldGridScrollView.swift
//  CherryBombSweeper
//
//  Created by Duy Nguyen on 1/19/18.
//  Copyright © 2018 Duy.Ninja. All rights reserved.
//

import UIKit

class FieldGridScrollView: UIScrollView {
    fileprivate var fieldGridCollection: FieldGridCollectionView?

    private var minScaleFactor: CGFloat = GameGeneralService.Constant.defaultMinScaleFactor
    
    private var rowCount: Int = 0
    private var columnCount: Int = 0
    private var fieldWidth: CGFloat = 0
    private var fieldHeight: CGFloat = 0
    private var modifiedIndexPaths: Set<IndexPath> = []
    
    fileprivate var lastZoomedWidth: CGFloat = 0
    
    fileprivate var topConstraint: NSLayoutConstraint?
    fileprivate var leadingConstraint: NSLayoutConstraint?
    
    lazy private var setUpOnce: Void = {
        self.delegate = self
        
        self.isScrollEnabled = true
        self.showsVerticalScrollIndicator = false
        self.showsHorizontalScrollIndicator = false
        
        let fieldGrid = FieldGridCollectionView(frame: self.frame, collectionViewLayout: FieldGridCollectionViewLayout())
        fieldGrid.backgroundColor = UIColor.clear
        fieldGrid.layer.borderWidth = GameGeneralService.Constant.fieldBorderWidth
        fieldGrid.layer.borderColor = UIColor.black.cgColor
        fieldGrid.isScrollEnabled = false
        self.fieldGridCollection = fieldGrid
        
        fieldGrid.isHidden = true
        
        self.addSubview(fieldGrid)
    }()
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let _ = setUpOnce
    }
    
    func setupFieldGrid(rows: Int, columns: Int,
                        dataSource: UICollectionViewDataSource,
                        cellActionHandler: FieldGridCellActionListener,
                        completionHandler: FieldSetupCompletionHandler?) {
        
        guard let fieldGridCollection = self.fieldGridCollection else { return }
        
        if rows == self.rowCount, columns == self.columnCount {
            // Dimension didn't change, so just reset it
            fieldGridCollection.dataSource = dataSource
            fieldGridCollection.cellActionHandler = cellActionHandler
            
            // Show and reload only what's been affected
            fieldGridCollection.isHidden = false
            fieldGridCollection.reloadItems(at: Array(self.modifiedIndexPaths))
            
            self.modifiedIndexPaths.removeAll()
            self.contentSize = CGSize(width: self.fieldWidth, height: self.fieldHeight)
            
            self.recenterFieldGrid()
            
            DispatchQueue.main.async {
                UIView.animate(withDuration: 0.3) {
                    self.zoomScale = 1.0
                    self.contentOffset.x = 0
                    self.contentOffset.y = 0
                }
                
                completionHandler?(self.fieldWidth, self.fieldHeight)
            }
            
            return
        }
        
        self.rowCount = rows
        self.columnCount = columns
        self.modifiedIndexPaths.removeAll()
        
        fieldGridCollection.setupFieldGrid(rows: rows, columns: columns, dataSource: dataSource, cellActionHandler: cellActionHandler) { [weak self] (fieldWidth, fieldHeight) in
            guard let `self` = self else { return }
            self.fieldWidth = fieldWidth
            self.fieldHeight = fieldHeight
            
            self.contentSize = CGSize(width: fieldWidth, height: fieldHeight)
            
            self.calculateGridLayoutParams(width: fieldWidth, height: fieldHeight)
            
            // Show and reload
            fieldGridCollection.isHidden = false
            fieldGridCollection.reloadData()
            
            DispatchQueue.main.async {
                UIView.animate(withDuration: 0.3) {
                    self.zoomScale = 1.0
                    self.contentOffset.x = 0
                    self.contentOffset.y = 0
                }
                
                completionHandler?(fieldWidth, fieldHeight)
            }
        }
    }
    
    private func calculateScaleFactors() {
        let windowWidth = self.frame.width
        let windowHeight = self.frame.height
        
        // Figure out which dimension is wider than screen when normalized, that dimension would determine the mininum scale factor
        // to fit the entire field into the container
        let screenAspect = windowWidth / windowHeight
        let fieldAspect = self.fieldWidth / self.fieldHeight
        
        let newMinScale = (fieldAspect > screenAspect) ? windowWidth / self.fieldWidth : windowHeight / self.fieldHeight
        
        if self.minScaleFactor < newMinScale {
            self.zoomScale = newMinScale
        }
        
        self.minScaleFactor = newMinScale
        
        self.minimumZoomScale = self.minScaleFactor
        self.maximumZoomScale = GameGeneralService.Constant.defaultMaxScaleFactor
    }
    
    func showEntireField() {
        UIView.animate(withDuration: 0.3) {
            self.zoomScale = self.minScaleFactor
            self.recenterFieldGrid()
        }
    }
    
    func updateCells(at indexPaths: [IndexPath]) {
        guard let fieldGridCollection = self.fieldGridCollection else { return }
        // keep track of which cell has been affected
        self.modifiedIndexPaths = self.modifiedIndexPaths.union(indexPaths)
        DispatchQueue.main.async {
            fieldGridCollection.reloadItems(at: indexPaths)
        }
    }
    
    func calculateGridLayoutParams(width: CGFloat? = nil, height: CGFloat? = nil) {
        self.calculateScaleFactors()
        self.lastZoomedWidth = 0
        self.recenterFieldGrid(width: width, height: height)
    }
    
    fileprivate func recenterFieldGrid(width: CGFloat? = nil, height: CGFloat? = nil) {
        guard self.lastZoomedWidth != self.contentSize.width,
            let fieldGrid = self.fieldGridCollection else { return }
        
        let fieldWidth = width ?? self.contentSize.width
        let fieldHeight = height ?? self.contentSize.height

        let windowWidth = self.frame.width
        let windowHeight = self.frame.height
        
        self.lastZoomedWidth = fieldWidth

        if fieldWidth > windowWidth, fieldHeight > windowHeight {
            self.resetConstraintsToOrigin()
        } else {
            self.leadingConstraint?.isActive = false
            self.topConstraint?.isActive = false
            
            if fieldWidth < windowWidth {
                // lockOffsetX
                let xOffset = (windowWidth - fieldWidth) / 2
                
                let leadingConstraint = fieldGrid.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: xOffset)
                self.leadingConstraint = leadingConstraint
            } else {
                let leadingConstraint = fieldGrid.leadingAnchor.constraint(equalTo: self.leadingAnchor)
                self.leadingConstraint = leadingConstraint
            }
            
            if fieldHeight < windowHeight {
                // lockOffsetY
                let yOffset = (windowHeight - fieldHeight) / 2
                
                let topConstraint = fieldGrid.topAnchor.constraint(equalTo: self.topAnchor, constant: yOffset)
                self.topConstraint = topConstraint
            } else {
                let topConstraint = fieldGrid.topAnchor.constraint(equalTo: self.topAnchor)
                self.topConstraint = topConstraint
            }
            
            self.topConstraint?.isActive = true
            self.leadingConstraint?.isActive = true
            
            DispatchQueue.main.async {
                UIView.animate(withDuration: 0.3) {
                    self.layoutIfNeeded()
                }
            }
        }
    }
    
    private func resetConstraintsToOrigin() {
        guard let fieldGrid = self.fieldGridCollection else { return }
        
        self.leadingConstraint?.isActive = false
        self.topConstraint?.isActive = false
        
        let leadingConstraint = fieldGrid.leadingAnchor.constraint(equalTo: self.leadingAnchor)
        self.leadingConstraint = leadingConstraint
        
        let topConstraint = fieldGrid.topAnchor.constraint(equalTo: self.topAnchor)
        self.topConstraint = topConstraint
        
        self.topConstraint?.isActive = true
        self.leadingConstraint?.isActive = true
        
        DispatchQueue.main.async {
            UIView.animate(withDuration: 0.3) {
                self.layoutIfNeeded()
            }
        }
    }
}

extension FieldGridScrollView: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return self.fieldGridCollection
    }
    
    func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        self.recenterFieldGrid()
    }
}

extension FieldGridScrollView: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}

