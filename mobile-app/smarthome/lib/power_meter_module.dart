import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:intl/intl.dart'; // Import intl package
import 'my_drawer.dart'; // Import the MyDrawer widget

class PowerMeterModulePage extends StatefulWidget {
  @override
  _PowerMeterModuleState createState() => _PowerMeterModuleState();
}

class _PowerMeterModuleState extends State<PowerMeterModulePage> {
  double current = 10.0;
  double voltage = 220.0;
  double powerConsumption = 2.2;
  double energyConsumption = 15.0;
  double threshold = 10.0;
  double powerFactor = 0.95;
  String selectedTimePeriod = 'Last 30 days';
  List<_EnergyConsumptionData> energyConsumptionData = [];

  @override
  void initState() {
    super.initState();
    _generateDummyData();
  }

  void _generateDummyData() {
    DateTime now = DateTime.now();
    energyConsumptionData.clear();
    for (int i = 0; i < 100; i++) {
      energyConsumptionData.add(
        _EnergyConsumptionData(
          date: now.subtract(Duration(days: i)),
          consumption: (i % 5 + 1) * 10.0,
        ),
      );
    }

    // Generate dummy data for the last 24 hours
    for (int i = 0; i < 24; i++) {
      energyConsumptionData.add(
        _EnergyConsumptionData(
          date: now.subtract(Duration(hours: i)),
          consumption: (i % 5 + 1) * 5.0,
        ),
      );
    }
  }

  List<_EnergyConsumptionData> _getFilteredData() {
    DateTime now = DateTime.now();
    Duration duration;
    switch (selectedTimePeriod) {
      case 'Last 24 hours':
        duration = Duration(hours: 24);
        break;
      case 'Last 7 days':
        duration = Duration(days: 7);
        break;
      default:
        duration = Duration(days: 30);
    }
    return energyConsumptionData
        .where((data) => data.date.isAfter(now.subtract(duration)))
        .toList();
  }

  void _updateThreshold(double value) {
    setState(() {
      threshold = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    List<_EnergyConsumptionData> filteredData = _getFilteredData();

    DateTimeAxis xAxis = DateTimeAxis(
      dateFormat: selectedTimePeriod == 'Last 24 hours'
          ? DateFormat.Hm()
          : DateFormat.MMMd(),
      intervalType: selectedTimePeriod == 'Last 24 hours'
          ? DateTimeIntervalType.hours
          : DateTimeIntervalType.days,
      majorGridLines: MajorGridLines(width: 0),
      axisLabelFormatter: (axisLabelRenderArgs) {
        final DateTime date = DateTime.fromMillisecondsSinceEpoch(
            axisLabelRenderArgs.value.toInt());
        if (selectedTimePeriod == 'Last 24 hours') {
          return ChartAxisLabel(DateFormat.Hm().format(date), TextStyle());
        } else {
          return ChartAxisLabel(DateFormat.MMMd().format(date), TextStyle());
        }
      },
    );
    return Scaffold(
      appBar: AppBar(
        title: Text('Power Meter Module'),
      ),
      drawer: MyDrawer(
        currentRoute: '/powerMeter',
        context: context,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Current: ',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text('$current A', style: TextStyle(fontSize: 18)),
              ],
            ),
            Row(
              children: [
                Text('Voltage: ',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text('$voltage V', style: TextStyle(fontSize: 18)),
              ],
            ),
            Row(
              children: [
                Text('Power Consumption: ',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text('$powerConsumption kW', style: TextStyle(fontSize: 18)),
              ],
            ),
            Row(
              children: [
                Text('Energy Consumption: ',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text('$energyConsumption kWh', style: TextStyle(fontSize: 18)),
              ],
            ),
            Row(
              children: [
                Text('Threshold: ',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text('${threshold.toInt()} kWh',
                    style: TextStyle(fontSize: 18)),
                Expanded(
                  child: Slider(
                    value: threshold,
                    min: 0,
                    max: 100,
                    label: threshold.round().toString(),
                    onChanged: _updateThreshold,
                    divisions: null,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Text('Power Factor: ',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text('$powerFactor', style: TextStyle(fontSize: 18)),
              ],
            ),
            SizedBox(height: 20),
            Text(
              'Energy Consumption Over Time:',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue),
            ),
            DropdownButton<String>(
              value: selectedTimePeriod,
              items: <String>['Last 24 hours', 'Last 7 days', 'Last 30 days']
                  .map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  selectedTimePeriod = newValue!;
                });
              },
            ),
            Expanded(
              child: SfCartesianChart(
                primaryXAxis: xAxis,
                primaryYAxis: NumericAxis(),
                series: <ChartSeries>[
                  LineSeries<_EnergyConsumptionData, DateTime>(
                    dataSource: filteredData,
                    xValueMapper: (_EnergyConsumptionData data, _) => data.date,
                    yValueMapper: (_EnergyConsumptionData data, _) =>
                        data.consumption,
                    markerSettings: MarkerSettings(isVisible: false),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EnergyConsumptionData {
  _EnergyConsumptionData({required this.date, required this.consumption});

  final DateTime date;
  final double consumption;
}
