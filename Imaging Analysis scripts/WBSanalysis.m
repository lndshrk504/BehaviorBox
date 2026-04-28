% Include the p-values
WHICH = pvalues >= 0.05; % The ID matrix
% Exclude those with metrics.SNR below 1

%Iterate over the rows in the ID matrix
%Decode this ID into a day and channel
%Load the spike.npy file for channels represented by the ID matric
%Average together the spikes.npy to create a tuning curve for the neuron