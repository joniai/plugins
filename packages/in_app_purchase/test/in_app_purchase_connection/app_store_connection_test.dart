// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:in_app_purchase/src/in_app_purchase/purchase_details.dart';
import 'package:test/test.dart';

import 'package:in_app_purchase/src/channel.dart';
import 'package:in_app_purchase/src/in_app_purchase/app_store_connection.dart';
import 'package:in_app_purchase/src/in_app_purchase/product_details.dart';
import 'package:in_app_purchase/store_kit_wrappers.dart';
import '../store_kit_wrappers/sk_test_stub_objects.dart';

void main() {
  final _FakeIOSPlatform fakeIOSPlatform = _FakeIOSPlatform();

  setUpAll(() {
    SystemChannels.platform
        .setMockMethodCallHandler(fakeIOSPlatform.onMethodCall);
  });

  setUp(() => fakeIOSPlatform.reset());

  tearDown(() => fakeIOSPlatform.reset());

  group('isAvailable', () {
    test('true', () async {
      expect(await AppStoreConnection.instance.isAvailable(), isTrue);
    });
  });

  group('query product list', () {
    test('should get product list and correct invalid identifiers', () async {
      final AppStoreConnection connection = AppStoreConnection();
      final ProductDetailsResponse response = await connection
          .queryProductDetails(<String>['123', '456', '789'].toSet());
      List<ProductDetails> products = response.productDetails;
      expect(
        products.first.id,
        '123',
      );
      expect(
        products[1].id,
        '456',
      );
      expect(
        response.notFoundIDs,
        ['789'],
      );
    });
  });

  group('query purchases list', () {
    test('should get purchase list', () async {
      QueryPurchaseDetailsResponse response =
          await AppStoreConnection.instance.queryPastPurchases();
      expect(response.pastPurchases.length, 2);
      expect(response.pastPurchases.first.purchaseID,
          fakeIOSPlatform.transactions.first.transactionIdentifier);
      expect(response.pastPurchases.last.purchaseID,
          fakeIOSPlatform.transactions.last.transactionIdentifier);
      expect(response.pastPurchases.first.purchaseID,
          fakeIOSPlatform.transactions.first.transactionIdentifier);
      expect(response.pastPurchases.last.purchaseID,
          fakeIOSPlatform.transactions.last.transactionIdentifier);
      expect(
          response.pastPurchases.first.verificationData.localVerificationData,
          'dummy base64data');
      expect(
          response.pastPurchases.first.verificationData.serverVerificationData,
          'dummy base64data');
      expect(response.error, isNull);
    });

    test('should get empty result if there is no restored transactions',
        () async {
      fakeIOSPlatform.testRestoredTransactionsNull = true;
      QueryPurchaseDetailsResponse response =
          await AppStoreConnection.instance.queryPastPurchases();
      expect(response.pastPurchases, isEmpty);
      fakeIOSPlatform.testRestoredTransactionsNull = false;
    });

    test('test restore error', () async {
      fakeIOSPlatform.testRestoredError = SKError(
          code: 123,
          domain: 'error_test',
          userInfo: {'message': 'errorMessage'});
      QueryPurchaseDetailsResponse response =
          await AppStoreConnection.instance.queryPastPurchases();
      expect(response.pastPurchases, isEmpty);
      expect(response.error.source, PurchaseSource.AppStore);
      expect(response.error.message['message'], 'errorMessage');
    });

    test('receipt error should populate null to verificationData.data',
        () async {
      fakeIOSPlatform.receiptData = null;
      QueryPurchaseDetailsResponse response =
          await AppStoreConnection.instance.queryPastPurchases();
      expect(
          response.pastPurchases.first.verificationData.localVerificationData,
          null);
      expect(
          response.pastPurchases.first.verificationData.serverVerificationData,
          null);
    });
  });

  group('refresh receipt data', () {
    test('should refresh receipt data', () async {
      PurchaseVerificationData receiptData =
          await AppStoreConnection.instance.refreshPurchaseVerificationData();
      expect(receiptData.source, PurchaseSource.AppStore);
      expect(receiptData.localVerificationData, 'refreshed receipt data');
      expect(receiptData.serverVerificationData, 'refreshed receipt data');
    });
  });

  group('make payment', () {
    test(
        'buying non consumable, should get purchase objects in the purchase update callback',
        () async {
      List<PurchaseDetails> details = [];
      Completer completer = Completer();
      Stream<List<PurchaseDetails>> stream =
          AppStoreConnection.instance.purchaseUpdatedStream;

      StreamSubscription subscription;
      subscription = stream.listen((purchaseDetailsList) {
        details.addAll(purchaseDetailsList);
        if (purchaseDetailsList.first.status == PurchaseStatus.purchased) {
          completer.complete(details);
          subscription.cancel();
        }
      });
      final PurchaseParam purchaseParam = PurchaseParam(
          productDetails: dummyProductWrapper.toProductDetails(),
          applicationUserName: 'appName');
      await AppStoreConnection.instance
          .buyNonConsumable(purchaseParam: purchaseParam);

      List<PurchaseDetails> result = await completer.future;
      expect(result.length, 2);
      expect(result.first.productID, dummyProductWrapper.productIdentifier);
    });

    test(
        'buying consumable, should get purchase objects in the purchase update callback',
        () async {
      List<PurchaseDetails> details = [];
      Completer completer = Completer();
      Stream<List<PurchaseDetails>> stream =
          AppStoreConnection.instance.purchaseUpdatedStream;

      StreamSubscription subscription;
      subscription = stream.listen((purchaseDetailsList) {
        details.addAll(purchaseDetailsList);
        if (purchaseDetailsList.first.status == PurchaseStatus.purchased) {
          completer.complete(details);
          subscription.cancel();
        }
      });
      final PurchaseParam purchaseParam = PurchaseParam(
          productDetails: dummyProductWrapper.toProductDetails(),
          applicationUserName: 'appName');
      await AppStoreConnection.instance
          .buyConsumable(purchaseParam: purchaseParam);

      List<PurchaseDetails> result = await completer.future;
      expect(result.length, 2);
      expect(result.first.productID, dummyProductWrapper.productIdentifier);
    });

    test('buying consumable, should throw when autoConsume is false', () async {
      final PurchaseParam purchaseParam = PurchaseParam(
          productDetails: dummyProductWrapper.toProductDetails(),
          applicationUserName: 'appName');
      expect(
          () => AppStoreConnection.instance
              .buyConsumable(purchaseParam: purchaseParam, autoConsume: false),
          throwsA(TypeMatcher<AssertionError>()));
    });

    test('should get failed purchase status', () async {
      fakeIOSPlatform.testTransactionFail = true;
      List<PurchaseDetails> details = [];
      Completer completer = Completer();
      PurchaseError error;

      Stream<List<PurchaseDetails>> stream =
          AppStoreConnection.instance.purchaseUpdatedStream;
      StreamSubscription subscription;
      subscription = stream.listen((purchaseDetailsList) {
        details.addAll(purchaseDetailsList);
        purchaseDetailsList.forEach((purchaseDetails) {
          if (purchaseDetails.status == PurchaseStatus.error) {
            error = purchaseDetails.error;
            completer.complete(error);
            subscription.cancel();
          }
        });
      });
      final PurchaseParam purchaseParam = PurchaseParam(
          productDetails: dummyProductWrapper.toProductDetails(),
          applicationUserName: 'appName');
      await AppStoreConnection.instance
          .buyNonConsumable(purchaseParam: purchaseParam);

      PurchaseError completerError = await completer.future;
      expect(completerError.code, kPurchaseErrorCode);
      expect(completerError.source, PurchaseSource.AppStore);
      expect(completerError.message, {'message': 'an error message'});
    });
  });

  group('complete purchase', () {
    test('should complete purchase', () async {
      List<PurchaseDetails> details = [];
      Completer completer = Completer();
      Stream<List<PurchaseDetails>> stream =
          AppStoreConnection.instance.purchaseUpdatedStream;
      StreamSubscription subscription;
      subscription = stream.listen((purchaseDetailsList) {
        details.addAll(purchaseDetailsList);
        purchaseDetailsList.forEach((purchaseDetails) {
          if (purchaseDetails.status == PurchaseStatus.purchased) {
            AppStoreConnection.instance.completePurchase(purchaseDetails);
            completer.complete(details);
            subscription.cancel();
          }
        });
      });
      final PurchaseParam purchaseParam = PurchaseParam(
          productDetails: dummyProductWrapper.toProductDetails(),
          applicationUserName: 'appName');
      await AppStoreConnection.instance
          .buyNonConsumable(purchaseParam: purchaseParam);
      List<PurchaseDetails> result = await completer.future;
      expect(result.length, 2);
      expect(result.first.productID, dummyProductWrapper.productIdentifier);
      expect(fakeIOSPlatform.finishedTransactions.length, 1);
    });
  });

  group('consume purchase', () {
    test('should throw when calling consume purchase on iOS', () async {
      expect(() => AppStoreConnection.instance.consumePurchase(null),
          throwsUnsupportedError);
    });
  });

  group('downloads', () {
    test('start download', () async {
      Map<String, SKDownloadWrapper> downloadsResult = Map();
      Completer firstCompleter = Completer();
      Completer activeCompleter = Completer();
      Completer finishCompleter = Completer();
      Stream<List<SKDownloadWrapper>> stream =
          AppStoreConnection.instance.downloadStream;

      StreamSubscription subscription;
      subscription = stream.listen((downloadList) {
        downloadList.forEach((download) {
          downloadsResult[download.contentIdentifier] = download;
        });
        if (downloadsResult['A'].state == SKDownloadState.waiting &&
            downloadsResult['B'].state == SKDownloadState.waiting) {
          firstCompleter.complete(downloadsResult);
        }
        if (downloadsResult['A'].state == SKDownloadState.active &&
            downloadsResult['B'].state == SKDownloadState.active) {
          activeCompleter.complete(downloadsResult);
        }
        if (downloadsResult['A'].state == SKDownloadState.finished &&
            downloadsResult['B'].state == SKDownloadState.finished) {
          finishCompleter.complete(downloadsResult);
          subscription.cancel();
        }
      });

      final SKDownloadWrapper downloadA = fakeIOSPlatform.createDownloadWithID(
          id: 'A', state: SKDownloadState.waiting);
      final SKDownloadWrapper downloadB = fakeIOSPlatform.createDownloadWithID(
          id: 'B', state: SKDownloadState.waiting);

      AppStoreConnection.instance.updateDownloads(
          downloads: [downloadA, downloadB],
          operation: SKDownloadOperation.start);

      Map<String, SKDownloadWrapper> startResult = await firstCompleter.future;
      expect(startResult.length, 2);
      expect(startResult['A'].state, SKDownloadState.waiting);
      expect(startResult['B'].state, SKDownloadState.waiting);

      Map<String, SKDownloadWrapper> activeResult =
          await activeCompleter.future;
      expect(activeResult.length, 2);
      expect(activeResult['A'].state, SKDownloadState.active);
      expect(activeResult['B'].state, SKDownloadState.active);

      Map<String, SKDownloadWrapper> finishResult =
          await activeCompleter.future;
      expect(finishResult.length, 2);
      expect(finishResult['A'].state, SKDownloadState.finished);
      expect(finishResult['B'].state, SKDownloadState.finished);
    });

    test('pause download', () async {
      Map<String, SKDownloadWrapper> downloadsResult = Map();
      Completer completer = Completer();
      Stream<List<SKDownloadWrapper>> stream =
          AppStoreConnection.instance.downloadStream;

      StreamSubscription subscription;
      subscription = stream.listen((downloadList) {
        downloadList.forEach((download) {
          downloadsResult[download.contentIdentifier] = download;
        });
        if (downloadsResult['A'].state == SKDownloadState.pause &&
            downloadsResult['B'].state == SKDownloadState.pause) {
          completer.complete(downloadsResult);
          subscription.cancel();
        } else {
          throw Exception('pause download should not have other state');
        }
      });

      final SKDownloadWrapper downloadA = fakeIOSPlatform.createDownloadWithID(
          id: 'A', state: SKDownloadState.waiting);
      final SKDownloadWrapper downloadB = fakeIOSPlatform.createDownloadWithID(
          id: 'B', state: SKDownloadState.waiting);

      AppStoreConnection.instance.updateDownloads(
          downloads: [downloadA, downloadB],
          operation: SKDownloadOperation.pause);

      Map<String, SKDownloadWrapper> result = await completer.future;
      expect(result.length, 2);
      expect(result['A'].state, SKDownloadState.pause);
      expect(result['B'].state, SKDownloadState.pause);
    });

    test('cancel download', () async {
      Map<String, SKDownloadWrapper> downloadsResult = Map();
      Completer completer = Completer();
      Stream<List<SKDownloadWrapper>> stream =
          AppStoreConnection.instance.downloadStream;

      StreamSubscription subscription;
      subscription = stream.listen((downloadList) {
        downloadList.forEach((download) {
          downloadsResult[download.contentIdentifier] = download;
        });
        if (downloadsResult['A'].state == SKDownloadState.cancelled &&
            downloadsResult['B'].state == SKDownloadState.cancelled) {
          completer.complete(downloadsResult);
          subscription.cancel();
        } else {
          throw Exception('pause download should not have other state');
        }
      });

      final SKDownloadWrapper downloadA = fakeIOSPlatform.createDownloadWithID(
          id: 'A', state: SKDownloadState.waiting);
      final SKDownloadWrapper downloadB = fakeIOSPlatform.createDownloadWithID(
          id: 'B', state: SKDownloadState.waiting);

      AppStoreConnection.instance.updateDownloads(
          downloads: [downloadA, downloadB],
          operation: SKDownloadOperation.cancel);

      Map<String, SKDownloadWrapper> result = await completer.future;
      expect(result.length, 2);
      expect(result['A'].state, SKDownloadState.cancelled);
      expect(result['B'].state, SKDownloadState.cancelled);
    });

    test('resume download', () async {
      Map<String, SKDownloadWrapper> downloadsResult = Map();
      Completer completer = Completer();
      Stream<List<SKDownloadWrapper>> stream =
          AppStoreConnection.instance.downloadStream;

      StreamSubscription subscription;
      subscription = stream.listen((downloadList) {
        downloadList.forEach((download) {
          downloadsResult[download.contentIdentifier] = download;
        });
        if (downloadsResult['A'].state == SKDownloadState.active &&
            downloadsResult['B'].state == SKDownloadState.active) {
          completer.complete(downloadsResult);
          subscription.cancel();
        } else {
          throw Exception('pause download should not have other state');
        }
      });

      final SKDownloadWrapper downloadA = fakeIOSPlatform.createDownloadWithID(
          id: 'A', state: SKDownloadState.waiting);
      final SKDownloadWrapper downloadB = fakeIOSPlatform.createDownloadWithID(
          id: 'B', state: SKDownloadState.waiting);

      AppStoreConnection.instance.updateDownloads(
          downloads: [downloadA, downloadB],
          operation: SKDownloadOperation.resume);

      Map<String, SKDownloadWrapper> result = await completer.future;
      expect(result.length, 2);
      expect(result['A'].state, SKDownloadState.active);
      expect(result['B'].state, SKDownloadState.active);
    });
  });
}

class _FakeIOSPlatform {
  _FakeIOSPlatform() {
    channel.setMockMethodCallHandler(onMethodCall);
  }

  // pre-configured store informations
  String receiptData;
  Set<String> validProductIDs;
  Map<String, SKProductWrapper> validProducts;
  List<SKPaymentTransactionWrapper> transactions;
  List<SKPaymentTransactionWrapper> finishedTransactions;
  bool testRestoredTransactionsNull;
  bool testTransactionFail;
  SKError testRestoredError;
  Map<String, SKDownloadWrapper> currentDownloads;

  void reset() {
    transactions = [];
    receiptData = 'dummy base64data';
    validProductIDs = ['123', '456'].toSet();
    validProducts = Map();
    for (String validID in validProductIDs) {
      Map productWrapperMap = buildProductMap(dummyProductWrapper);
      productWrapperMap['productIdentifier'] = validID;
      validProducts[validID] = SKProductWrapper.fromJson(productWrapperMap);
    }

    SKPaymentTransactionWrapper tran1 = SKPaymentTransactionWrapper(
      transactionIdentifier: '123',
      payment: dummyPayment,
      originalTransaction: dummyTransaction,
      transactionTimeStamp: 123123123.022,
      transactionState: SKPaymentTransactionStateWrapper.restored,
      error: null,
    );
    SKPaymentTransactionWrapper tran2 = SKPaymentTransactionWrapper(
      transactionIdentifier: '1234',
      payment: dummyPayment,
      originalTransaction: dummyTransaction,
      transactionTimeStamp: 123123123.022,
      transactionState: SKPaymentTransactionStateWrapper.restored,
      error: null,
    );

    transactions.addAll([tran1, tran2]);
    finishedTransactions = [];
    testRestoredTransactionsNull = false;
    testTransactionFail = false;
    testRestoredError = null;

    currentDownloads = Map();
  }

  SKPaymentTransactionWrapper _createPendingTransactionWithProductID(
      String id) {
    return SKPaymentTransactionWrapper(
        payment: SKPaymentWrapper(productIdentifier: id),
        transactionState: SKPaymentTransactionStateWrapper.purchasing,
        transactionTimeStamp: 123123.121,
        transactionIdentifier: id,
        error: null,
        originalTransaction: null);
  }

  SKPaymentTransactionWrapper _createPurchasedTransactionWithProductID(
      String id) {
    return SKPaymentTransactionWrapper(
        payment: SKPaymentWrapper(productIdentifier: id),
        transactionState: SKPaymentTransactionStateWrapper.purchased,
        transactionTimeStamp: 123123.121,
        transactionIdentifier: id,
        error: null,
        originalTransaction: null);
  }

  SKPaymentTransactionWrapper _createFailedTransactionWithProductID(String id) {
    return SKPaymentTransactionWrapper(
        payment: SKPaymentWrapper(productIdentifier: id),
        transactionState: SKPaymentTransactionStateWrapper.failed,
        transactionTimeStamp: 123123.121,
        transactionIdentifier: id,
        error: SKError(
            code: 0,
            domain: 'ios_domain',
            userInfo: {'message': 'an error message'}),
        originalTransaction: null);
  }

  SKDownloadWrapper createDownloadWithID({String id, SKDownloadState state}) {
    return SKDownloadWrapper(
      contentIdentifier: id,
      state: state,
      contentLength: 32,
      contentURL: 'https://download.com',
      contentVersion: '0.0.1',
      transactionID: 'tranID',
      progress: 0.6,
      timeRemaining: 1231231,
      downloadTimeUnknown: false,
      error: dummyError,
    );
  }

  Future<dynamic> onMethodCall(MethodCall call) {
    switch (call.method) {
      case '-[SKPaymentQueue canMakePayments:]':
        return Future<bool>.value(true);
      case '-[InAppPurchasePlugin startProductRequest:result:]':
        List<String> productIDS =
            List.castFrom<dynamic, String>(call.arguments);
        assert(productIDS is List<String>, 'invalid argument type');
        List<String> invalidFound = [];
        List<SKProductWrapper> products = [];
        for (String productID in productIDS) {
          if (!validProductIDs.contains(productID)) {
            invalidFound.add(productID);
          } else {
            products.add(validProducts[productID]);
          }
        }
        SkProductResponseWrapper response = SkProductResponseWrapper(
            products: products, invalidProductIdentifiers: invalidFound);
        return Future<Map<String, dynamic>>.value(
            buildProductResponseMap(response));
      case '-[InAppPurchasePlugin restoreTransactions:result:]':
        if (testRestoredError != null) {
          AppStoreConnection.observer
              .restoreCompletedTransactionsFailed(error: testRestoredError);
          return Future<void>.sync(() {});
        }
        if (!testRestoredTransactionsNull) {
          AppStoreConnection.observer
              .updatedTransactions(transactions: transactions);
        }
        AppStoreConnection.observer
            .paymentQueueRestoreCompletedTransactionsFinished();
        return Future<void>.sync(() {});
      case '-[InAppPurchasePlugin retrieveReceiptData:result:]':
        if (receiptData != null) {
          return Future<void>.value(receiptData);
        } else {
          throw PlatformException(code: 'no_receipt_data');
        }
        break;
      case '-[InAppPurchasePlugin refreshReceipt:result:]':
        receiptData = 'refreshed receipt data';
        return Future<void>.sync(() {});
      case '-[InAppPurchasePlugin addPayment:result:]':
        String id = call.arguments['productIdentifier'];
        SKPaymentTransactionWrapper transaction =
            _createPendingTransactionWithProductID(id);
        AppStoreConnection.observer
            .updatedTransactions(transactions: [transaction]);
        sleep(const Duration(milliseconds: 30));
        if (testTransactionFail) {
          SKPaymentTransactionWrapper transaction_failed =
              _createFailedTransactionWithProductID(id);
          AppStoreConnection.observer
              .updatedTransactions(transactions: [transaction_failed]);
        } else {
          SKPaymentTransactionWrapper transaction_finished =
              _createPurchasedTransactionWithProductID(id);
          AppStoreConnection.observer
              .updatedTransactions(transactions: [transaction_finished]);
        }
        break;
      case '-[InAppPurchasePlugin finishTransaction:result:]':
        finishedTransactions
            .add(_createPurchasedTransactionWithProductID(call.arguments));
        break;
      case '-[InAppPurchasePlugin updateDownloads:result:]':
        List<String> downloadIDs =
            List.castFrom<dynamic, String>(call.arguments['downloads']);
        SKDownloadOperation operation = SKDownloadOperation.values
            .firstWhere((e) => e.toString() == call.arguments['operation']);

        switch (operation) {
          case SKDownloadOperation.start:
            List<SKDownloadWrapper> downloads = List();
            for (String id in downloadIDs) {
              assert(currentDownloads[id] == null);
              SKDownloadWrapper download =
                  createDownloadWithID(id: id, state: SKDownloadState.waiting);
              currentDownloads[id] = download;
              downloads.add(download);
            }
            AppStoreConnection.observer.updatedDownloads(downloads: downloads);

            sleep(const Duration(milliseconds: 30));
            downloads = downloadIDs.map((String downloadID) {
              return currentDownloads[downloadID];
            }).map((SKDownloadWrapper download) {
              currentDownloads[download.contentIdentifier] =
                  createDownloadWithID(
                      id: download.contentIdentifier,
                      state: SKDownloadState.active);
              return currentDownloads[download.contentIdentifier];
            }).toList();
            AppStoreConnection.observer.updatedDownloads(downloads: downloads);

            sleep(const Duration(milliseconds: 30));
            downloads = downloadIDs.map((String downloadID) {
              return currentDownloads[downloadID];
            }).map((SKDownloadWrapper download) {
              currentDownloads[download.contentIdentifier] =
                  createDownloadWithID(
                      id: download.contentIdentifier,
                      state: SKDownloadState.finished);
              return currentDownloads[download.contentIdentifier];
            }).toList();
            AppStoreConnection.observer.updatedDownloads(downloads: downloads);
            break;
          case SKDownloadOperation.pause:
            List<SKDownloadWrapper> downloads = List();
            for (String id in downloadIDs) {
              assert(currentDownloads[id] == null);
              SKDownloadWrapper download =
                  createDownloadWithID(id: id, state: SKDownloadState.pause);
              currentDownloads[id] = download;
              downloads.add(download);
            }
            AppStoreConnection.observer.updatedDownloads(downloads: downloads);
            break;
          case SKDownloadOperation.cancel:
            List<SKDownloadWrapper> downloads = List();
            for (String id in downloadIDs) {
              assert(currentDownloads[id] == null);
              SKDownloadWrapper download = createDownloadWithID(
                  id: id, state: SKDownloadState.cancelled);
              currentDownloads[id] = download;
              downloads.add(download);
            }
            AppStoreConnection.observer.updatedDownloads(downloads: downloads);
            break;
          case SKDownloadOperation.resume:
            List<SKDownloadWrapper> downloads = List();
            for (String id in downloadIDs) {
              assert(currentDownloads[id] == null);
              SKDownloadWrapper download =
                  createDownloadWithID(id: id, state: SKDownloadState.active);
              currentDownloads[id] = download;
              downloads.add(download);
            }
            AppStoreConnection.observer.updatedDownloads(downloads: downloads);
            break;
            break;
          default:
        }
        break;
    }
    return Future<void>.sync(() {});
  }
}
