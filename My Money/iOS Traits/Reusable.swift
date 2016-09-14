import UIKit

/// Make your UITableViewCell and UICollectionViewCell subclasses
/// conform to this protocol when they are *not* NIB-based but only code-based
/// to be able to dequeue them in a type-safe manner
public protocol Reusable: class {
  /// The reuse identifier to use when registering and later dequeuing a reusable cell
  static var reuseIdentifier: String { get }
}

/// Make your UITableViewCell and UICollectionViewCell subclasses
/// conform to this protocol when they *are* NIB-based
/// to be able to dequeue them in a type-safe manner
public protocol NibReusable: Reusable, NibLoadable {}

// MARK: - Default implementation for Reusable

public extension Reusable {
  /// By default, use the name of the class as String for its reuseIdentifier
  static var reuseIdentifier: String {
    return String(describing: self)
  }
}

// MARK: - UITableView support for Reusable & NibReusable

public extension UITableView {
  /**
   Register a NIB-Based `UITableViewCell` subclass (conforming to `NibReusable`)

   - parameter cellType: the `UITableViewCell` (`NibReusable`-conforming) subclass to register

   - seealso: `registerNib(_:,forCellReuseIdentifier:)`
   */
  final func registerReusableCell<T: UITableViewCell>(_ cellType: T.Type) where T: NibReusable {
    self.register(T.nib, forCellReuseIdentifier: T.reuseIdentifier)
  }

  /**
   Register a Class-Based `UITableViewCell` subclass (conforming to `Reusable`)

   - parameter cellType: the `UITableViewCell` (`Reusable`-conforming) subclass to register

   - seealso: `registerClass(_:,forCellReuseIdentifier:)`
   */
  final func registerReusableCell<T: UITableViewCell>(_ cellType: T.Type) where T: Reusable {
    self.register(T.self, forCellReuseIdentifier: T.reuseIdentifier)
  }

  /**
   Returns a reusable `UITableViewCell` object for the class inferred by the return-type

   - parameter indexPath: The index path specifying the location of the cell.
   - parameter cellType: The cell class to dequeue

   - returns: A `Reusable`, `UITableViewCell` instance

   - note: The `cellType` parameter can generally be omitted and infered by the return type,
           except when your type is in a variable and cannot be determined at compile time.
   - seealso: `dequeueReusableCellWithIdentifier(_:,forIndexPath:)`
   */
  final func dequeueReusableCell<T: UITableViewCell>(indexPath: IndexPath, cellType: T.Type = T.self) -> T where T: Reusable {
    guard let cell = self.dequeueReusableCell(withIdentifier: cellType.reuseIdentifier, for: indexPath) as? T else {
      fatalError(
        "Failed to dequeue a cell with identifier \(cellType.reuseIdentifier) matching type \(cellType.self). "
          + "Check that the reuseIdentifier is set properly in your XIB/Storyboard "
          + "and that you registered the cell beforehand"
      )
    }
    return cell
  }

  /**
   Register a NIB-Based `UITableViewHeaderFooterView` subclass (conforming to `NibReusable`)

   - parameter viewType: the `UITableViewHeaderFooterView` (`NibReusable`-conforming) subclass to register

   - seealso: `registerNib(_:,forHeaderFooterViewReuseIdentifier:)`
   */
  final func registerReusableHeaderFooterView<T: UITableViewHeaderFooterView>(_ viewType: T.Type) where T: NibReusable {
    self.register(T.nib, forHeaderFooterViewReuseIdentifier: T.reuseIdentifier)
  }

  /**
   Register a Class-Based `UITableViewHeaderFooterView` subclass (conforming to `Reusable`)

   - parameter viewType: the `UITableViewHeaderFooterView` (`Reusable`-confirming) subclass to register

   - seealso: `registerClass(_:,forHeaderFooterViewReuseIdentifier:)`
   */
  final func registerReusableHeaderFooterView<T: UITableViewHeaderFooterView>(_ viewType: T.Type) where T: Reusable {
    self.register(T.self, forHeaderFooterViewReuseIdentifier: T.reuseIdentifier)
  }

  /**
   Returns a reusable `UITableViewHeaderFooterView` object for the class inferred by the return-type

   - parameter viewType: The view class to dequeue

   - returns: A `Reusable`, `UITableViewHeaderFooterView` instance

   - note: The `viewType` parameter can generally be omitted and infered by the return type,
           except when your type is in a variable and cannot be determined at compile time.
   - seealso: `dequeueReusableHeaderFooterViewWithIdentifier(_:)`
   */
  final func dequeueReusableHeaderFooterView<T: UITableViewHeaderFooterView>(_ viewType: T.Type = T.self) -> T? where T: Reusable {
    guard let view = self.dequeueReusableHeaderFooterView(withIdentifier: viewType.reuseIdentifier) as? T? else {
      fatalError(
        "Failed to dequeue a header/footer with identifier \(viewType.reuseIdentifier) matching type \(viewType.self). "
          + "Check that the reuseIdentifier is set properly in your XIB/Storyboard "
          + "and that you registered the header/footer beforehand"
      )
    }
    return view
  }
}

// MARK: - UICollectionView support for Reusable & NibReusable

public extension UICollectionView {
  /**
   Register a NIB-Based `UICollectionViewCell` subclass (conforming to `NibReusable`)

   - parameter cellType: the `UICollectionViewCell` (`NibReusable`-conforming) subclass to register

   - seealso: `registerNib(_:,forCellWithReuseIdentifier:)`
   */
  final func registerReusableCell<T: UICollectionViewCell>(_ cellType: T.Type) where T: NibReusable {
    self.register(T.nib, forCellWithReuseIdentifier: T.reuseIdentifier)
  }

  /**
   Register a Class-Based `UICollectionViewCell` subclass (conforming to `Reusable`)

   - parameter cellType: the `UICollectionViewCell` (`Reusable`-conforming) subclass to register

   - seealso: `registerClass(_:,forCellWithReuseIdentifier:)`
   */
  final func registerReusableCell<T: UICollectionViewCell>(_ cellType: T.Type) where T: Reusable {
    self.register(T.self, forCellWithReuseIdentifier: T.reuseIdentifier)
  }

  /**
   Returns a reusable `UICollectionViewCell` object for the class inferred by the return-type

   - parameter indexPath: The index path specifying the location of the cell.
   - parameter cellType: The cell class to dequeue

   - returns: A `Reusable`, `UICollectionViewCell` instance

   - note: The `cellType` parameter can generally be omitted and infered by the return type,
           except when your type is in a variable and cannot be determined at compile time.
   - seealso: `dequeueReusableCellWithReuseIdentifier(_:,forIndexPath:)`
   */
  final func dequeueReusableCell<T: UICollectionViewCell>(indexPath: IndexPath, cellType: T.Type = T.self) -> T where T: Reusable {
    guard let cell = self.dequeueReusableCell(withReuseIdentifier: cellType.reuseIdentifier, for: indexPath) as? T else {
      fatalError(
        "Failed to dequeue a cell with identifier \(cellType.reuseIdentifier) matching type \(cellType.self). "
          + "Check that the reuseIdentifier is set properly in your XIB/Storyboard "
          + "and that you registered the cell beforehand"
      )
    }
    return cell
  }

  /**
   Register a NIB-Based `UICollectionReusableView` subclass (conforming to `NibReusable`) as a Supplementary View

   - parameter elementKind: The kind of supplementary view to create.
   - parameter viewType: the `UIView` (`NibReusable`-conforming) subclass to register as Supplementary View

   - seealso: `registerNib(_:,forSupplementaryViewOfKind:,withReuseIdentifier:)`
   */
  final func registerReusableSupplementaryView<T: UICollectionReusableView>(_ elementKind: String, viewType: T.Type) where T: NibReusable {
    self.register(T.nib, forSupplementaryViewOfKind: elementKind, withReuseIdentifier: T.reuseIdentifier)
  }

  /**
   Register a Class-Based `UICollectionReusableView` subclass (conforming to `Reusable`) as a Supplementary View

   - parameter elementKind: The kind of supplementary view to create.
   - parameter viewType: the `UIView` (`Reusable`-conforming) subclass to register as Supplementary View

   - seealso: `registerClass(_:,forSupplementaryViewOfKind:,withReuseIdentifier:)`
   */
  final func registerReusableSupplementaryView<T: UICollectionReusableView>(_ elementKind: String, viewType: T.Type) where T: Reusable {
    self.register(T.self, forSupplementaryViewOfKind: elementKind, withReuseIdentifier: T.reuseIdentifier)
  }

  /**
   Returns a reusable `UICollectionReusableView` object for the class inferred by the return-type

   - parameter elementKind: The kind of supplementary view to retrieve.
   - parameter indexPath:   The index path specifying the location of the cell.
   - parameter viewType: The view class to dequeue

   - returns: A `Reusable`, `UICollectionReusableView` instance

   - note: The `viewType` parameter can generally be omitted and infered by the return type,
           except when your type is in a variable and cannot be determined at compile time.
   - seealso: `dequeueReusableSupplementaryViewOfKind(_:,withReuseIdentifier:,forIndexPath:)`
   */
	final func dequeueReusableSupplementaryView<T: UICollectionReusableView>
		(_ elementKind: String, indexPath: IndexPath, viewType: T.Type = T.self) -> T where T: Reusable {
      let view = self.dequeueReusableSupplementaryView(ofKind: elementKind, withReuseIdentifier: viewType.reuseIdentifier, for: indexPath)
    guard let typedView = view as? T else {
      fatalError(
        "Failed to dequeue a supplementary view with identifier \(viewType.reuseIdentifier) matching type \(viewType.self). "
          + "Check that the reuseIdentifier is set properly in your XIB/Storyboard "
          + "and that you registered the supplementary view beforehand"
      )
    }
    return typedView
  }
}
