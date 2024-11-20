# Create a virtual machine image from a blob

This example is intended to demonstrate the process of using a VHD as a source for creating an image. 

In this example, an unmanaged disk is used to simulate a VHD that has been uploaded from an on-premises environment to Azure. Unmanaged disks are generally not recommended for production environments due to limitations in scalability, performance, and manageability. This VHD, stored in a storage account, will serve as the source for creating the image for future VM deployments. 

If you plan to use your own VHD, make sure to follow all the necessary steps to prepare the VHD for upload to  Azure as described [here](https://learn.microsoft.com/en-us/azure/virtual-machines/windows/prepare-for-upload-vhd-image).
