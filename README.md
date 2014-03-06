# Cloud processing with Envisat ASAR data and GTMSAR

This repository contains the application files and scripts to process a stack with one master and one or more slaves of Envisat ASAR data with [GMTSAR](http://topex.ucsd.edu/gmtsar/) an InSAR processing system based on [GMT](http://gmt.soest.hawaii.edu/) to process SAR images to create InSAR images, named interferograms.

To run this application, you will need a Developer Cloud Sandbox that can be either requested from the ESA research & service support Portal (http://eogrid.esrin.esa.int/cloudtoolbox/) for ESA G-POD related projects and ESA registered user accounts, or directly from Terradue's Portal (http://www.terradue.com/partners), provided user registration approval.

A Developer Cloud Sandbox provides Earth Science data access services, and assistance tools for a user to implement, test and validate his application. It runs in two different lifecycle modes: sandbox mode and cluster mode. Used in Sandbox mode (single virtual machine), it supports cluster simulation and user assistance functions in building the distributed application. Used in Cluster mode (collections of virtual machines), it supports the deployment and execution of the application with the power of distributed computing processing over large datasets (leveraging the Hadoop Streaming MapReduce technology).

### Installation

1. Log on the `app gmtsar` sandbox via SSH

2. Install GMTSAR

### Getting started

We will process an Envisat ASAR stack with one master and two slaves  

The application is described in the Application Descriptor file (application.xml), it describes two processing nodes:
* processing step `msd`
* processing step `gmtsar`

#### Processing step `msd`

The processing step `msd` (Master, Slave, DEM) takes the three Envisat ASAR datasets references (one master and two slaves):

* http://catalogue.terradue.int/catalogue/search/ASA_IM__0P/ASA_IM__0CNPDE20090412_092426_000000162078_00079_37207_1556.N1/rdf (master)
* http://catalogue.terradue.int/catalogue/search/ASA_IM__0P/ASA_IM__0CNPAM20080427_092430_000000172068_00079_32197_3368.N1/rdf (slave 1)
* http://catalogue.terradue.int/catalogue/search/ASA_IM__0P/ASA_IM__0CNPAM20070128_092433_000000162055_00079_25684_2263.N1/rdf (slave 2)

> These products are also available on the European Space Agency (ESA) virtual archive available at http://eo-virtual-archive4.esa.int

> 1. Open a browser on http://eo-virtual-archive4.esa.int/?bbox=13.18,42.26,13.56,42.46 (this sets the AOI over L'Aquila)
2. In the "Search" input box write "ASA_IM__0P" to limit the results to Envisat ASAR Image Mode Level 0
3. Set the track range from 79 to 79
4. Set the start date to "2007-01-01" and stop date to "2009-04-15
5. Click "Search"
6. Select on the left side the master: ASA_IM__0CNPDE20090412_092426_000000162078_00079_37207_1556.N1
7. Below the map, on the "Related tab", you'll see candidate slave products

The `msd` processing tasks are: 

* extend the master product footprint of 0.2 degrees
* invoke the [GTMSAR Generate DEM Service](http://topex.ucsd.edu/gmtsar/demgen/) with the extended master footprint
* download the GTMSAR Generate DEM Service result and publish it in the Sandbox distributed filesystem 
* generate the inputs for the `gmtsar` processing step which are triplets of 
 * the master SAR product reference
 * the slave SAR product reference
 * the DEM product reference

With the data defined in the [application.xml](https://github.com/Terradue/InSAR-tutorials-GMTSAR/blob/master/application.xml), the processing step `msd` produces the triplets:

* triplet 1
 * http://catalogue.terradue.int/catalogue/search/ASA_IM__0P/ASA_IM__0CNPDE20090412_092426_000000162078_00079_37207_1556.N1/rdf (master)
 * http://catalogue.terradue.int/catalogue/search/ASA_IM__0P/ASA_IM__0CNPAM20080427_092430_000000172068_00079_32197_3368.N1/rdf (slave 1)
 * the DEM  
* triplet 2
 * http://catalogue.terradue.int/catalogue/search/ASA_IM__0P/ASA_IM__0CNPDE20090412_092426_000000162078_00079_37207_1556.N1/rdf (master)
 * http://catalogue.terradue.int/catalogue/search/ASA_IM__0P/ASA_IM__0CNPAM20070128_092433_000000162055_00079_25684_2263.N1/rdf (slave 2) 
 * the DEM 

#### Processing step `gmtsar`

The `gmtsar` processing step takes as inputs the references to the `msd` processing step outputs to generate the interferogram out of the Envisat ASAR stack of products.

The `gmtsar` processing tasks are: 

* For each triplet
 * Copy the generated DEM to the working directory 
 * Copy the master ASAR product to the working directory
 * Copy the slave ASAR prodcut to the working directory
 * Invoke GMTSAR's `run_envi_csh` script to convert to the RAW format
 * Publish the results

### Running the application 

#### Run the processing steps one after the other:

From the `Sandbox gmtsar` shell, to submit the execution of the worklflow node `msd` run:

`$ ciop-simjob -f msd`

Then, with the inputs from the above `msd` execution, the `gmtsar` can be submitted: 

`$ ciop-simjob -f gmtsar`

#### Run the processing steps in a single step:

`$ ciop-simwf`

This will submit the complete worflow with nodes `msd` and `gmtsar`

#### Run the processing service via the dashboard

The Sandbox dashboard allows submitting and monitoring an OGC WPS request with a GUI

On a Browser:
* Type the address http://sandbox_ip/dashboard
* Click the Invoke tab
* Fill the processing request with one master and one or more slave products
* Submit the process by clicking "Run"

#### Run the processing service via OGC WPS

Using HTTP GET request with `curl`

`curl http://sandbox_ip/wps/?service=WPS&request=Execute&version=1.0.0&Identifier=&storeExecuteResponse=true&status=true&DataInputs=sar1=http://catalogue.terradue.int/catalogue/search/ASA_IM__0P/ASA_IM__0CNPDE20100502_175016_000000172089_00084_42723_0354.N1/rdf;sar2=http://catalogue.terradue.int/catalogue/search/ASA_IM__0P/ASA_IM__0CNPDE20100328_175019_000000162088_00084_42222_9504.N1/rdf`

Using HTTP POST request with `curl`

TBW


### References

* [Developer Cloud Sandbox](https://support.terradue.com/projects/devel-cloud-sb/wiki)
* [ESA Virtual Archive - access SAR data](http://eo-virtual-archive4.esa.int/)
* [GMTSAR Web Site](http://topex.ucsd.edu/gmtsar/)
* [GTMSAR Generate DEM Service](http://topex.ucsd.edu/gmtsar/demgen/)
* [SSEP CloudToolbox](http://eogrid.esrin.esa.int/cloudtoolbox/) to request a Developer Cloud Sandbox PaaS and run this application
