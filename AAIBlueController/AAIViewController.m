//
//  AAIViewController.m
//  AAIBlueController
//
//  Created by Kyle Oba on 5/7/14.
//  Copyright (c) 2014 AgencyAgency. All rights reserved.
//

#import "AAIViewController.h"

#define PDC_BLE_HM10_SERVICE_UUID @"FFE0"
#define PDC_BLE_HM10_CHARACTERISTIC_UUID @"FFE1"

@interface AAIViewController ()

@property (nonatomic, strong) NSString *connected;
@property (weak, nonatomic) IBOutlet UILabel *connectionLabel;
@property (weak, nonatomic) IBOutlet UITextView *statusTextView;
@property (nonatomic, strong) NSString *status;


@property (weak, nonatomic) IBOutlet UITextField *userInputTextField;
@property (weak, nonatomic) IBOutlet UIButton *sendButton;
@property (strong, nonatomic) CBCharacteristic *activeCharacteristic;
@end

@implementation AAIViewController

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        _status = @"";
    }
    return self;
}

- (void)setActiveCharacteristic:(CBCharacteristic *)activeCharacteristic
{
    _activeCharacteristic = activeCharacteristic;
    self.sendButton.enabled = YES;
}

- (void)setConnected:(NSString *)connected
{
    _connected = connected;
    self.connectionLabel.text = connected;
}

- (void)scanForDevices
{
    // Scan for all available CoreBluetooth LE devices
	NSArray *services = @[[CBUUID UUIDWithString:PDC_BLE_HM10_SERVICE_UUID]];
	CBCentralManager *centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
	[centralManager scanForPeripheralsWithServices:services options:nil];
	self.centralManager = centralManager;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    [self scanForDevices];
}

- (void)setStatus:(NSString *)status
{
    _status = status;
    self.statusTextView.text = status;
}

- (NSString *)appendStatusMessage:(NSString *)message
{
    NSString *log = [self.status copy];
    NSLog(@"%@", log);
    return [log stringByAppendingString:[NSString stringWithFormat:@"\n%@", message]];
}

- (void)sendDeviceText:(NSString *)text
{
    NSData *data = [text dataUsingEncoding:NSUTF8StringEncoding];
    [self.peripheral writeValue:data
              forCharacteristic:self.activeCharacteristic
                           type:CBCharacteristicWriteWithoutResponse];
}

- (IBAction)sendMessagePressed:(UIButton *)sender
{
    [self sendDeviceText:self.userInputTextField.text];
}

- (IBAction)directionButtonPressed:(UIButton *)sender
{
    [self sendDeviceText:sender.titleLabel.text];
}

#pragma mark - CBCentralManagerDelegate

// method called whenever you have successfully connected to the BLE peripheral
- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    NSLog(@"Connected to peripheral: %@", peripheral);
    
    [peripheral setDelegate:self];
    [peripheral discoverServices:nil];
    self.connected = [NSString stringWithFormat:@"Connected: %@", peripheral.state == CBPeripheralStateConnected ? @"YES" : @"NO"];
    NSLog(@"%@", self.connected);
}

// CBCentralManagerDelegate - This is called with the CBPeripheral class as its main input parameter. This contains most of the information there is to know about a BLE peripheral.
- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI
{
    NSLog(@"Discovered peripheral: %@", peripheral);

    NSString *localName = [advertisementData objectForKey:CBAdvertisementDataLocalNameKey];
    if ([localName length] > 0) {
        NSLog(@"Found a thing: %@", localName);
        [self.centralManager stopScan];
        self.peripheral = peripheral;
        peripheral.delegate = self;
        [self.centralManager connectPeripheral:peripheral options:nil];
    }
}

// method called whenever the device state changes.
- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    NSLog(@"Updated central: %@", central);
    
    // Determine the state of the peripheral
    if ([central state] == CBCentralManagerStatePoweredOff) {
        NSLog(@"CoreBluetooth BLE hardware is powered off");
    }
    else if ([central state] == CBCentralManagerStatePoweredOn) {
        NSLog(@"CoreBluetooth BLE hardware is powered on and ready");
    }
    else if ([central state] == CBCentralManagerStateUnauthorized) {
        NSLog(@"CoreBluetooth BLE state is unauthorized");
    }
    else if ([central state] == CBCentralManagerStateUnknown) {
        NSLog(@"CoreBluetooth BLE state is unknown");
    }
    else if ([central state] == CBCentralManagerStateUnsupported) {
        NSLog(@"CoreBluetooth BLE hardware is unsupported on this platform");
    }
}


#pragma mark - CBPeripheralDelegate

// CBPeripheralDelegate - Invoked when you discover the peripheral's available services.
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    NSLog(@"did discover services");
    
    for (CBService *service in peripheral.services) {
        NSString *log = [NSString stringWithFormat:@"Discovered service: %@", service.UUID];
        self.status = [self appendStatusMessage:log];
        
        [peripheral discoverCharacteristics:nil forService:service];
    }
}

// Invoked when you discover the characteristics of a specified service.
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
    NSLog(@"discovered characteristics for service: %@", service);
    
    if ([service.UUID isEqual:[CBUUID UUIDWithString:PDC_BLE_HM10_SERVICE_UUID]]) {
        for (CBCharacteristic *aChar in service.characteristics) {
            if ([aChar.UUID isEqual:[CBUUID UUIDWithString:PDC_BLE_HM10_CHARACTERISTIC_UUID]]) {
                [self.peripheral setNotifyValue:YES forCharacteristic:aChar];
//                [self.peripheral readValueForCharacteristic:aChar];
                self.status = [self appendStatusMessage:[NSString stringWithFormat:@"Found our thing characteristic: %@", aChar]];
                self.activeCharacteristic = aChar;
            }
        }
    }
}

// Invoked when you retrieve a specified characteristic's value, or when the peripheral device notifies your app that the characteristic's value has changed.
- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    NSLog(@"did update value for characteristic: %@", characteristic);
    
    // Updated value for heart rate measurement received
    if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:PDC_BLE_HM10_CHARACTERISTIC_UUID]]) {
        self.status = [self appendStatusMessage:[NSString stringWithFormat:@"updated value for characteristic: %@", characteristic]];
        
        NSString *dataString = [[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding];
        self.status = [self appendStatusMessage:[NSString stringWithFormat:@"value: %@", dataString]];
    }
}


@end
