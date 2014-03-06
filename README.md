# Cloud processing with Envisat ASAR data and GTMSAR

This repository contains the application files and scripts to process a pair of Envisat ASAR data with [GMTSAR](http://topex.ucsd.edu/gmtsar/) an InSAR processing system based on [GMT](http://gmt.soest.hawaii.edu/) to process SAR images to create InSAR images, named interferograms.

To run this application, you will need a Developer Cloud Sandbox that can be either requested from the ESA research & service support Portal (http://eogrid.esrin.esa.int/cloudtoolbox/) for ESA G-POD related projects and ESA registered user accounts, or directly from Terradue's Portal (http://www.terradue.com/partners), provided user registration approval.

A Developer Cloud Sandbox provides Earth Science data access services, and assistance tools for a user to implement, test and validate his application. It runs in two different lifecycle modes: sandbox mode and cluster mode. Used in Sandbox mode (single virtual machine), it supports cluster simulation and user assistance functions in building the distributed application. Used in Cluster mode (collections of virtual machines), it supports the deployment and execution of the application with the power of distributed computing processing over large datasets (leveraging the Hadoop Streaming MapReduce technology).

### Installation

1. Log on the `app roi_pac` sandbox via SSH

2. Install GMTSAR

### Getting started

We will process an Envisat pair  
