# Create a virtual machine image that includes a data disk from a blob

This example is intended to demonstrate the process of using VHDs as a source for creating a master image that includes both the OS disk and the data disk. 

In this example, unmanaged disks are used to simulate VHDs that have been uploaded from an on-premises environment to Azure. Unmanaged disks are generally not recommended for production environments due to limitations in scalability, performance, and manageability. These VHDs, stored in a storage account, will serve as the source for creating a master image for future VM deployments. 

If you plan to use your own VHDs, make sure to follow all the necessary steps to prepare the VHDs for upload to  Azure as described [here](https://learn.microsoft.com/en-us/azure/virtual-machines/windows/prepare-for-upload-vhd-image).
