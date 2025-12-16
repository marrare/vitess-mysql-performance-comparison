import matplotlib.pyplot as plt
import numpy as np

x = np.linspace(0, 10, 100)
y = np.sin(x)

plt.plot(x, y)
plt.title("Simple Sine Wave Plot")
plt.xlabel("X-axis Label")
plt.ylabel("Y-axis Label")
plt.show()