# Create a virtual machine image from an existing virtual machine

This example demonstrates how to prepare both Windows and Linux virtual machines as base configurations for creating a managed image. The process involves deprovisioning or generalizing the VM to remove any machine-specific data, ensuring the virtual machine is in a clean, reusable state before capturing it as an image.

For the Linux VM, the Azure VM Agent (waagent) is used to deprovision the machine, removing all machine-specific files and sensitive data to ensure it is generalized for use as a base image. The Windows VM undergoes a similar process, with Sysprep being run to remove all personal accounts, security settings, and unique identifiers, followed by deallocation and generalization.

Both VMs will be deallocated and generalized to create a clean image that can be used to provision additional VMs. After generalizing, the VMs will serve as the source for generating a managed image in Azure.
