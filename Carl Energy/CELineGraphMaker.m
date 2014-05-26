//
//  CELineGraphMaker.m
//  Carl Energy
//
//  Created by Larkin Flodin on 5/25/14.
//  Copyright (c) 2014 Carleton College. All rights reserved.
//

#import "CELineGraphMaker.h"

@implementation CELineGraphMaker

- (void)requestDataOfType:(UsageType)type forBuilding:(CEBuilding*)building forTimeScale:(CETimeScale)timeScale
{
    NSLog(@"Request Data of Type");
    // get some dummy data to test if the request works
    
    if (!self.retreiver) {
        self.retreiver = [[CEDataRetriever alloc] init];
        [self.retreiver setDelegate:self];
    }

    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy/MM/dd+HH:mm:ss"];
    NSDate *now = [NSDate date];
    NSDate *previous;
    Resolution resolution;
    CPTXYAxisSet *axisSet = (CPTXYAxisSet *) self.lineGraph.axisSet;
    self.x = axisSet.xAxis;
    switch (timeScale) {
        case kTimeScaleDay:
            previous = [now dateByAddingTimeInterval:-60*60*24];
            resolution = kResolutionHour;
            self.x.title = @"Hour";
            self.requestType = 0;
            break;
        case kTimeScaleWeek:
            previous = [now dateByAddingTimeInterval:-60*60*24*7];
            resolution = kResolutionDay;
            self.x.title = @"Day ";
            self.requestType = 1;
            break;
        case kTimeScaleMonth:
            previous = [now dateByAddingTimeInterval:-60*60*24*30];
            resolution = kResolutionDay;
            self.x.title = @"Day";
            self.requestType = 2;
            break;
        case kTimeScaleYear:
            previous = [now dateByAddingTimeInterval:-60*60*24*365];
            resolution = kResolutionMonth;
            self.x.title = @"Month";
            self.requestType = 3;
            break;
        default:
            break;
    }
    
    //TODO: cancel request if another one is in progress
    if (!self.retreiver.requestInProgress) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^ {
            [self.retreiver getUsage:type ForBuilding:building startTime:previous endTime:now resolution:resolution];
        });
    }
}



- (CPTGraph *)makeLineGraphForTime:(NSInteger)timeframeIndex forUsage:(UsageType)type forBuilding:(CEBuilding*)building
{
    NSLog(@"MAKELINECALLED");
    // prep stuff
    switch (timeframeIndex)
    {
        case 0:
            [self requestDataOfType:type forBuilding:building forTimeScale:kTimeScaleDay];
            break;
        case 1:
            [self requestDataOfType:type forBuilding:building forTimeScale:kTimeScaleWeek];
            break;
        case 2:
            [self requestDataOfType:type forBuilding:building forTimeScale:kTimeScaleMonth];
            break;
        case 3:
            [self requestDataOfType:type forBuilding:building forTimeScale:kTimeScaleYear];
            break;
        default:
            break;
    }
    CEDataRetriever *retriever = [[CEDataRetriever alloc] init];
    [retriever setDelegate:self];
    NSUInteger numObjects = [self.dataForChart count];
    self.dataForChart = [[NSMutableArray alloc] init];
    self.dataForClearChart = [[NSMutableArray alloc] init];
    for (int i = 1; i <= numObjects; i++) {
        [self.dataForClearChart addObject:@0];
    }
    
    // Create and assign the host view
    self.lineGraph = [[CPTXYGraph alloc] initWithFrame:CGRectZero];
    
    // Define the textStyle for the title
    CPTMutableTextStyle *textStyle = [CPTMutableTextStyle textStyle];
    textStyle.color = [CPTColor darkGrayColor];
    textStyle.fontName = @"HelveticaNeue-Thin";
    textStyle.fontSize = 20.0f;
    
    // Make title
    NSString *title = @"";
    if (type == kUsageTypeElectricity) {
        self.energyType = kUsageTypeElectricity;
        title = @"Electricity Usage";
    }
    else if (type == kUsageTypeWater) {
        self.energyType = kUsageTypeWater;
        title = @"Water Usage";
    }
    else {
        self.energyType = kUsageTypeSteam;
        title = @"Steam Usage";
    }
    self.lineGraph.title = title;
    self.lineGraph.titleTextStyle = textStyle;
    //lineGraph.titlePlotAreaFrameAnchor = CPTRectAnchorTop;
    self.lineGraph.titleDisplacement = CGPointMake(0.0f, 40.0f);
    
    // Set plot area padding
    [self.lineGraph.plotAreaFrame setPaddingLeft:40.0f];
    [self.lineGraph.plotAreaFrame setPaddingBottom:100.0f];
     self.lineGraph.plotAreaFrame.masksToBorder = NO;
    
    // Create plot
    CPTXYPlotSpace *plotSpace = (CPTXYPlotSpace *) self.lineGraph.defaultPlotSpace;
    CPTScatterPlot *elecPlot = [[CPTScatterPlot alloc] init];
    elecPlot.dataSource = self;
    elecPlot.identifier = CEElectric;
    CPTColor *elecColor = [CPTColor redColor];
    CPTMutableLineStyle *elecLineStyle = [elecPlot.dataLineStyle mutableCopy];
    elecLineStyle.lineColor = elecColor;
    elecPlot.dataLineStyle = elecLineStyle;
    [self.lineGraph addPlot:elecPlot toPlotSpace:plotSpace];
    CPTScatterPlot *msftPlot = [[CPTScatterPlot alloc] init];
	msftPlot.dataSource = self;
	msftPlot.identifier = CEClear;
	CPTColor *msftColor = [CPTColor clearColor];
    CPTMutableLineStyle *msftLineStyle = [msftPlot.dataLineStyle mutableCopy];
    msftLineStyle.lineColor = msftColor;
    msftPlot.dataLineStyle = msftLineStyle;
	[self.lineGraph addPlot:msftPlot toPlotSpace:plotSpace];
    
    // Configure plot space
    // do we want to use the next line?
    [plotSpace scaleToFitPlots:[NSArray arrayWithObjects:elecPlot, msftPlot, nil]];
    CPTMutablePlotRange *xRange = [plotSpace.xRange mutableCopy];
    [xRange expandRangeByFactor:CPTDecimalFromCGFloat(1.3f)];
    plotSpace.xRange = xRange;
    CPTMutablePlotRange *yRange = [plotSpace.yRange mutableCopy];
    [yRange expandRangeByFactor:CPTDecimalFromCGFloat(1.3f)];
    plotSpace.yRange = yRange;
    
    
    
    // TODO: clean up this code
    // Configure axes
    // 1 - Create styles
    CPTMutableTextStyle *axisTitleStyle = [CPTMutableTextStyle textStyle];
    axisTitleStyle.color = [CPTColor blackColor];
    axisTitleStyle.fontName = @"Helvetica-Bold";
    axisTitleStyle.fontSize = 12.0f;
    CPTMutableLineStyle *axisLineStyle = [CPTMutableLineStyle lineStyle];
    axisLineStyle.lineWidth = 2.0f;
    axisLineStyle.lineColor = [CPTColor blackColor];
    CPTMutableTextStyle *axisTextStyle = [[CPTMutableTextStyle alloc] init];
    axisTextStyle.color = [CPTColor blackColor];
    axisTextStyle.fontName = @"Helvetica-Bold";
    axisTextStyle.fontSize = 10.0f;
    CPTMutableLineStyle *tickLineStyle = [CPTMutableLineStyle lineStyle];
    tickLineStyle.lineColor = [CPTColor blackColor];
    tickLineStyle.lineWidth = 2.0f;
    CPTMutableLineStyle *gridLineStyle = [CPTMutableLineStyle lineStyle];
    tickLineStyle.lineColor = [CPTColor blackColor];
    tickLineStyle.lineWidth = 1.0f;
    // 2 - Get axis set
    CPTXYAxisSet *axisSet = (CPTXYAxisSet *) self.lineGraph.axisSet;
    // 3 - Configure x-axis
    self.x = axisSet.xAxis;
    //self.x.title = @"Hour";
    self.x.titleTextStyle = axisTitleStyle;
    self.x.titleOffset = 15.0f;
    self.x.axisLineStyle = axisLineStyle;
    self.x.labelingPolicy = CPTAxisLabelingPolicyNone;
    self.x.labelTextStyle = axisTextStyle;
    self.x.majorTickLineStyle = axisLineStyle;
    self.x.majorTickLength = 4.0f;
    self.x.tickDirection = CPTSignNegative;
    //NSLog([NSString stringWithFormat:@"%i", day]);
    CGFloat dateCount = 24;
    NSMutableSet *xLabels = [NSMutableSet setWithCapacity:dateCount];
    NSMutableSet *xLocations = [NSMutableSet setWithCapacity:dateCount];
    for (int k = 1; k <= 24; k++) {
        if (k % 2 == 0) {
            NSString *myString = [NSString stringWithFormat:@"%i", k];
            CPTAxisLabel *label = [[CPTAxisLabel alloc] initWithText:myString textStyle:self.x.labelTextStyle];
            CGFloat location = k;
            label.tickLocation = CPTDecimalFromCGFloat(location);
            label.offset = self.x.majorTickLength;
            if (label) {
                [xLabels addObject:label];
                [xLocations addObject:[NSNumber numberWithFloat:location]];
            }
        }
    }
    self.x.axisLabels = xLabels;
    self.x.majorTickLocations = xLocations;
    // 4 - Configure y-axis
    self.y = axisSet.yAxis;
    if (type == kUsageTypeElectricity) {
        self.y.title = @"kW";
    }
    else {
        self.y.title = @"gallons";
    }
    self.y.titleTextStyle = axisTitleStyle;
    self.y.titleOffset = -40.0f;
    self.y.axisLineStyle = axisLineStyle;
    self.y.majorGridLineStyle = gridLineStyle;
    self.y.labelingPolicy = CPTAxisLabelingPolicyNone;
    self.y.labelTextStyle = axisTextStyle;
    self.y.labelOffset = 16.0f;
    self.y.majorTickLineStyle = axisLineStyle;
    self.y.majorTickLength = 4.0f;
    self.y.minorTickLength = 2.0f;
    self.y.tickDirection = CPTSignPositive;
    NSInteger majorIncrement = 10;
    
    //NSLog([NSString stringWithFormat:@"%@", [self.dataForElectricityChart objectAtIndex:0]]);
    CGFloat yMax = 200.0f;  // should determine dynamically
    NSMutableSet *yLabels = [NSMutableSet set];
    NSMutableSet *yMajorLocations = [NSMutableSet set];
    NSMutableSet *yMinorLocations = [NSMutableSet set];
    for (NSInteger j = majorIncrement; j <= yMax; j += majorIncrement) {
//        NSUInteger mod = j % majorIncrement;
        CPTAxisLabel *label = [[CPTAxisLabel alloc] initWithText:[NSString stringWithFormat:@"%li", (long)j] textStyle:self.y.labelTextStyle];
        NSDecimal location = CPTDecimalFromInteger(j);
        label.tickLocation = location;
        label.offset = -self.y.majorTickLength - self.y.labelOffset;
        if (label) {
            [yLabels addObject:label];
        }
        [yMajorLocations addObject:[NSDecimalNumber decimalNumberWithDecimal:location]];
        
    }
    self.y.axisLabels = yLabels;
    self.y.majorTickLocations = yMajorLocations;
    self.y.minorTickLocations = yMinorLocations;
    self.lineGraph.axisSet = axisSet;
    
    return self.lineGraph;
    
    
}

#pragma mark - CPTPlotDataSource methods
-(NSUInteger)numberOfRecordsForPlot:(CPTPlot *)plot {
    return [self.dataForChart count];
}

-(NSNumber *)numberForPlot:(CPTPlot *)plot field:(NSUInteger)fieldEnum recordIndex:(NSUInteger)index {
    switch (fieldEnum) {
        case CPTScatterPlotFieldX:
            return @(index);
            break;

        case CPTScatterPlotFieldY: {
            if ([plot.identifier isEqual:CEElectric] == YES) {
				NSNumber *yValue = [self.dataForChart objectAtIndex:index];

                return yValue;}
            else if ([plot.identifier isEqual:CEClear] == YES) {
				NSNumber *yValue = [self.dataForClearChart objectAtIndex:index];
                return yValue;
			}
			break;
        }
    }
    return [NSDecimalNumber zero];

}

#pragma mark - CEDataRetreiverDelegate methods
- (void)retriever:(CEDataRetriever *)retriever gotUsage:(NSArray *)usage ofType:(UsageType)usageType forBuilding:(CEBuilding *)building {
    [self.dataForChart removeAllObjects];
    for (CEDataPoint *point in usage) {
        [self.dataForChart addObject:@(point.weight * point.value)];
    }
    [self performSelectorOnMainThread:@selector(reloadPlotData) withObject:nil waitUntilDone:NO];
}

- (void)reloadPlotData {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy/MM/dd+HH:mm:ss"];
    NSDateComponents *components = [[NSCalendar currentCalendar] components:NSHourCalendarUnit |NSCalendarUnitDay | NSCalendarUnitMonth fromDate:[NSDate date]];
    NSInteger hour = [components hour];
    NSInteger day = [components day];
    NSInteger month = [components month];
    CGFloat dateCount = 24;
    NSMutableSet *xLabels = [NSMutableSet setWithCapacity:dateCount];
    NSMutableSet *xLocations = [NSMutableSet setWithCapacity:dateCount];
    NSUInteger numObjects = [self.dataForChart count];
    if (self.requestType == 0){
        NSLog(@"DAY INCREMENT");
        self.x.title = @"Hour";
        NSString *kString;
        for (int k = 1; k <= numObjects; k++) {
            if (k % 6 == 3) {
                NSInteger newK = hour - (24 - k);
                if (newK < 0)
                    newK = 24 + newK;
                if (newK > 12){
                    newK = newK - 12;
                    kString = [NSString stringWithFormat:@"%li%@", (long)newK,@"pm"];
                }
                else if (newK == 0){
                    kString = @"12am";
                }
                else{
                    kString = [NSString stringWithFormat:@"%li%@", (long)newK,@"am"];
                }
                CPTAxisLabel *label = [[CPTAxisLabel alloc] initWithText:kString  textStyle:self.x.labelTextStyle];
                CGFloat location = k;
                label.tickLocation = CPTDecimalFromCGFloat(location);
                label.offset = self.x.majorTickLength;
                if (label) {
                    [xLabels addObject:label];
                    [xLocations addObject:[NSNumber numberWithFloat:location]];
                }
            }
        }
    }
    else if (self.requestType == 1){
        NSLog(@"WEEK INCREMENT");
        self.x.title = @"Day";
        for (int k = 1; k <= numObjects; k++) {
            if (k%2 == 0){
                NSInteger newK = day - (7 - k);
                NSString *myString = [NSString stringWithFormat:@"%li%s%li", (long)month, "/",(long)newK];
                CPTAxisLabel *label = [[CPTAxisLabel alloc] initWithText:myString  textStyle:self.x.labelTextStyle];
                CGFloat location = k;
                label.tickLocation = CPTDecimalFromCGFloat(location);
                label.offset = self.x.majorTickLength;
                if (label) {
                    [xLabels addObject:label];
                    [xLocations addObject:[NSNumber numberWithFloat:location]];
                }
            }
        }
    }
    else if (self.requestType == 2){
        NSLog(@"MONTH INCREMENT");
        self.x.title = @"Day";
        for (int k = 1; k <= numObjects; k++) {
            if (k % 7 == 0) {
                NSInteger newK = day - (30 - k);
                if (newK < 0){
                    newK = day + (30 + k);
                }
                NSString *myString = [NSString stringWithFormat:@"%li%s%li", (long)month, "/",(long)newK];
                              // NSString *myString = [NSString stringWithFormat:@"%i", k];
                CPTAxisLabel *label = [[CPTAxisLabel alloc] initWithText:myString  textStyle:self.x.labelTextStyle];
                CGFloat location = k;
                label.tickLocation = CPTDecimalFromCGFloat(location);
                label.offset = self.x.majorTickLength;
                if (label) {
                    [xLabels addObject:label];
                    [xLocations addObject:[NSNumber numberWithFloat:location]];
                }
            }
        }
    }
    else if (self.requestType == 3){
        NSLog(@"YEAR INCREMENT");
        self.x.title = @"Month";
        for (int k = 1; k <= numObjects; k++) {
            if (k % 2 == 0) {
                NSInteger newK = month - (12 - k);
                if (newK < 1){
                    newK = month + k;
                }
                NSString *myString = [NSString stringWithFormat:@"%li",(long)newK];
                //NSString *myString = [NSString stringWithFormat:@"%i", k];
                CPTAxisLabel *label = [[CPTAxisLabel alloc] initWithText:myString  textStyle:self.x.labelTextStyle];
                CGFloat location = k;
                label.tickLocation = CPTDecimalFromCGFloat(location);
                label.offset = self.x.majorTickLength;
                if (label) {
                    [xLabels addObject:label];
                    [xLocations addObject:[NSNumber numberWithFloat:location]];
                }
            }
        }
    }
    
    
    NSNumber * max = [self.dataForChart valueForKeyPath:@"@max.intValue"];
    int maxInt = [max intValue];
    for (int i = 1; i <= numObjects; i++) {
        [self.dataForClearChart addObject:@0];
    }
    [self.lineGraph reloadData];
    if (self.energyType == kUsageTypeElectricity) {
        self.y.title = @"kW";
    }
    else if (self.energyType == kUsageTypeWater) {
        self.y.title = @"gallons";
    }
    else
        self.y.title =@"kBtus";
    if (maxInt == 0) {
        maxInt = 1;
    }
    NSInteger majorIncrement = ceil(maxInt/5.);
    NSLog(@"majorIncrement: %lu, maxInt: %i", (long)majorIncrement, maxInt);
    CGFloat yMax = maxInt;
    NSMutableSet *yLabels = [NSMutableSet set];
    NSMutableSet *yMajorLocations = [NSMutableSet set];
    for (NSInteger j = majorIncrement; j <= yMax; j += majorIncrement) {
        long jRound = j;
        if (maxInt < 100){
            jRound = (j/2) * 2;
        }
        else if (maxInt < 1000){
            jRound = (j/10) * 10;
        }
        else if (maxInt < 10000){
            jRound = (j/100) * 100;
        }
        else if (maxInt < 100000){
            jRound = (j/1000) * 1000;
        }
        else if (maxInt > 100000){
            jRound = (j/1000) * 1000;
        }
        CPTAxisLabel *label = [[CPTAxisLabel alloc] initWithText:[NSString stringWithFormat:@"%li", (long)jRound] textStyle:self.y.labelTextStyle];
        if (jRound > 999){
            NSMutableString *strLabel = [NSMutableString stringWithFormat:@"%li", (long)jRound];
            NSString *newString = [strLabel substringToIndex:[strLabel length]-3];
            NSMutableString *stringLabel = [NSMutableString stringWithFormat:@"%@%s", newString, "k"];
            label = [[CPTAxisLabel alloc] initWithText:[NSString stringWithFormat:@"%@", stringLabel] textStyle:self.y.labelTextStyle];
        }
        NSDecimal location = CPTDecimalFromInteger(j);
        label.tickLocation = location;
        label.offset = -self.y.majorTickLength - self.y.labelOffset;
        if (label) {
            [yLabels addObject:label];
        }
        [yMajorLocations addObject:[NSDecimalNumber decimalNumberWithDecimal:location]];
        
    }

    self.x.axisLabels = xLabels;
    self.x.majorTickLocations = xLocations;
    
    self.y.axisLabels = yLabels;
    self.y.majorTickLocations = yMajorLocations;
    [self.lineGraph.defaultPlotSpace scaleToFitPlots:[self.lineGraph allPlots]];
    
}

@end
