Build ubuntu image for rockchip rk35xx machines

Instructions:

1. Create rootfs
  
      ./mkrootfs.sh focal
  
      You can run it multiple times. If you think there is a problem with the created rootfs, you can clear it:
  
      ./mkrootfs.sh focal clean

2. Create target image

      For example:
  
      ./mkimg.sh rk3568 h68k focal

3. Get the target image:
  
      build/h68k_ubuntu_focal_vYYYYMMDD.img

4. System Requirements：

      x86_64 host: debian or ubuntu
      
      arm64 host: debian or ubuntu or armbian
      
      Storage space: >= 8GB
