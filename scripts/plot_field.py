import numpy as np
import matplotlib.pyplot as plt
import glob

files = sorted(glob.glob('data/phi.csv.*'))
for file in files:
    num = int(file.split('.')[-1])
    data = np.genfromtxt(file, delimiter=', ', skip_header=1)
    print(data)
    print(data.shape)
    print(np.max(data[:,0]))
    image = np.zeros((int(np.max(data[:,0]))+1,int(np.max(data[:,1]))+1))
    image[data[:,0].astype(int),data[:,1].astype(int)] = data[:,2]
    print(image.shape)
    plt.figure()
    plt.imshow(image)
    plt.savefig('plots/phi_%04d.png' % (num//2))
    plt.close()