this is what the uni rules states "**Grading and Assessment Rules**
Your artefact will be directly assessed by your markers under two main rubric categories. 
*   **Quality of Products:** This evaluates the final software system itself, and your markers will judge the artefact based on the **complexity or difficulty of the task and the degree of success achieved**.
*   **Quality of Processes:** This evaluates *how* you built and tested the system, meaning that to achieve a First-Class mark (70+), your **implementation and testing must be thorough, and your design must be precise and methodical**.

**Experimental Design Requirements**
According to your literature matrix, your artefact cannot be an arbitrary experimental environment. It must adhere to the following design restrictions:
*   **Real-world Compliance:** Your Kafka setup must be realistic and standards-compliant. You must actively justify your use of TLS, Access Control Lists (ACLs), and authentication to ensure the experimental configuration accurately reflects real-world systems.
*   **Evaluating Trade-offs:** The core purpose of your artefact is to provide empirical evidence and support the quantitative evaluation of the performance trade-offs between security (TLS/mTLS) and throughput.

**Benchmarking Restrictions**
When testing your artefact, you must adhere to rigorous benchmarking methodologies rather than casual observation.
*   **Primary Metric:** You must use throughput as the primary evaluation metric for your system.
*   **Multiple Workloads:** You are restricted from relying on a single benchmark case, meaning you **must test the artefact under multiple scenarios and traffic workloads** to ensure a robust evaluation.

**Data and Ethical Restrictions**
There are strict rules regarding the data you feed into your artefact during your testing phase. 
*   **Technical Data:** If your artefact uses public datasets that are purely technical (such as machine logs, algorithm sorting speeds, or weather data), **no human ethics approval is required**.
*   **Human Data:** If your testing involves *any* human data (such as social media scrapes, facial images, or medical data), **you must obtain formal ethics approval before any activity commences**. Conducting tests without this prior approval constitutes an ethics breach, which can result in a loss of marks, disciplinary action, or a delay in obtaining your degree."