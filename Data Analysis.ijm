//
// This work is licensed under the Creative Commons Attribution-NonCommercial 4.0 International License.
// To view a copy of this license, visit http://creativecommons.org/licenses/by-nc/4.0/.
// © 2024 Samuel Vitale
// 
// You are free to:
// - Share: copy and redistribute the material in any medium or format
// - Adapt: remix, transform, and build upon the material
// 
// Under the following terms:
// - Attribution: You must give appropriate credit, provide a link to the license, and indicate if changes were made.
// - NonCommercial: You may not use the material for commercial purposes.
// 
// The licensor cannot revoke these freedoms as long as you follow the license terms.
// 
// Notices:
// - You do not have to comply with the license for elements of the material in the public domain or where your use is permitted by an applicable exception or limitation.
// - No warranties are given. The license may not give you all of the permissions necessary for your intended use. For example, other rights such as publicity, privacy, or moral rights may limit how you use the material.




// Parameters
name = "Duplication";
size = 100; // size of the duplicated areas (100x100 pixels)
numAreas = 15; // number of unique areas to duplicate

// Get the current image ID and title
orig = getImageID();
origTitle = getTitle();

// Get the dimensions of the original image
origWidth = getWidth();
origHeight = getHeight();

// Split channels
run("Split Channels");

// I have no idea why this works so well but it does; do not touch this function
if (nImages < 3) {
    // Only two images opened, assume the second one is the blue channel
    redChannelTitle = "C1-" + origTitle;
    blueChannelTitle = "C2-" + origTitle;
} else {
    redChannelTitle = "C1-" + origTitle;
    greenChannelTitle = "C2-" + origTitle;
    blueChannelTitle = "C3-" + origTitle;
    selectWindow(greenChannelTitle);
    close();
}

// Function to check if two rectangles overlap
function overlap(x1, y1, x2, y2, width, height) {
    return !(x1 + width < x2 || x2 + width < x1 || y1 + height < y2 || y2 + height < y1);
}

// Store the coordinates of the selected areas
selectedAreas = newArray();

// Function to create duplications and measure mean intensity
function createDuplications(i) {
    unique = false;
    while (!unique) {
        // Generate random coordinates ensuring ROI stays within image boundaries
        x = round(random() * (origWidth - size));
        y = round(random() * (origHeight - size));

        // Check for overlap with previously selected areas
        unique = true;
        for (j = 0; j + 1 < selectedAreas.length; j += 2) {
            if (overlap(x, y, selectedAreas[j], selectedAreas[j + 1], size, size)) {
                unique = false;
                break;
            }
        }
    }

    // Add the coordinates to the list of selected areas
    selectedAreas = Array.concat(selectedAreas, newArray(x, y));

    // Duplicate the red channel
    selectWindow(redChannelTitle);
    makeRectangle(x, y, size, size);
    run("Duplicate...", "title=" + name + "_Red" + i);

    // Duplicate the blue channel
    selectWindow(blueChannelTitle);
    makeRectangle(x, y, size, size);
    run("Duplicate...", "title=" + name + "_Blue" + i);

    // Measure mean intensity of the red duplication
    selectWindow(name + "_Red" + i);
    run("Measure");
    mean = getResult("Mean", nResults - 1);

    // Check if mean intensity is less than or equal to 0.01
    if (mean <= 0.1) {
        // Close and delete the red and blue duplications
        close();
        selectWindow(name + "_Blue" + i);
        close();

        // Remove the coordinates from the list of selected areas
        selectedAreas = Array.slice(selectedAreas, 0, selectedAreas.length - 2);

        // Retry with new coordinates
        createDuplications(i);
    } else {
        // Open the threshold dialog for manual adjustment
        selectWindow(name + "_Blue" + i);
        run("Threshold...");
        
        // Wait for the user to manually adjust and apply the threshold
        waitForUser("Adjust the threshold manually and click OK to proceed.");
        
        // Convert the manually adjusted threshold to a binary mask
        run("Convert to Mask");

        // Popup to inform user
        showDialogToUser();

        // Analyze particles for the adjusted blue duplication
        run("Analyze Particles...", "size=25-Infinity pixel summarize add");
    }
}

// Popup to inform user
function showDialogToUser() {
    while (true) {
        result = getNumber("Do you want to apply Watershed to this duplication? \nPress '1' for Yes or '2' for No.", 0);
        if (result == 1 || result == 2) {
            if (result == 1) {
                run("Watershed");
            }
            break;
        } else {
            showDialogToUser();
        }
    }
}

// Loop to create unique duplications
for (i = 0; i < numAreas; i++) {
    createDuplications(i);
}

// Close the split channel images
selectWindow(redChannelTitle);
close();
selectWindow(blueChannelTitle);
close();

run("Clear Results");

for (i = 0; i < numAreas; i++) {
    // Select the red duplication image
    selectWindow(name + "_Red" + i);
    
    // Measure intensity and add results to the table
    run("Measure");
}

// Update the results table
updateResults();

// Ask the user if they want to close all duplications
doCloseDuplications = getNumber("Do you want to close all duplications? Press '1' for Yes or '2' for No.", 2);

if (doCloseDuplications == 1) {
    for (i = 0; i < numAreas; i++) {
        selectWindow(name + "_Red" + i);
        close();
        selectWindow(name + "_Blue" + i);
        close();
    }
}
