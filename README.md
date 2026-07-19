# Complete Smart Home System with Enhanced Safety Features

IoT smart-home graduation project with embedded safety modules, PCB design, MQTT communication, Python server, database, Flutter mobile app and custom mechanical designs.

It was designed for home automation and safety-oriented monitoring for fire, flooding, motion, door opening, temperature, alarms, electrical loads, and power availability.

> The original implementation used a MQTT broker locally configured, a Python server, a database and hardware modules based on ESP8266. To reproduce live functionality, the local environment must be rebuilt and configured.

## Project resources

- [Android application release](../../releases/latest)
- [Mechanical designs on GrabCAD](https://grabcad.com/library/complete-smart-home-system-with-enhanced-safety-features-1)
- [Final project report](https://drive.google.com/file/d/1AwJD1UMMyeOQV9r7DHtg-fEgsQMXAIIb/view?usp=sharing)
- [Academic poster](https://drive.google.com/file/d/1HJPEl7pNxOwpySByrP_OhR2CXyU3-c1F/view?usp=sharing)
- [Final presentation](https://drive.google.com/file/d/1ijiyFpCKpJ4Y58pfwwHIocHStm_BWEi7/view?usp=sharing)

## System overview

The project is based on ESP8266 modules connected over a local network. MQTT allows messages exchange between hardware, Python server and mobile application. The server interfaces with the database of the project.

<p align="center">
  <a href="docs/project-overview/All%20in%20One%20Schematic.jpg">
    <img src="docs/project-overview/All%20in%20One%20Schematic.jpg"
         alt="Complete smart-home system schematic"
         width="900">
  </a>
</p>

<p align="center">
  <em>Open the image to inspect the full-resolution system schematic.</em>
</p>
