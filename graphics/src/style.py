import matplotlib.pyplot as plt

def apply_paper_style():
    plt.rcParams.update({
        "figure.figsize": (7, 4.5),
        "figure.dpi": 120,
        "font.size": 9,
        "axes.titleweight": "semibold",
        "axes.grid": False,
        "savefig.dpi": 300,
        "savefig.bbox": "tight",
    })
