import os
import time
from collections import Counter

import pandas as pd
import requests
import streamlit as st

st.set_page_config(page_title="Auto Scaling Live Dashboard", layout="wide")

# In EC2/ECS this points at the ALB DNS name, e.g.
# http://your-alb-1234.ap-south-1.elb.amazonaws.com/api/v1
BACKEND_URL = os.environ.get("BACKEND_URL", "http://localhost:5000")

if "history" not in st.session_state:
    st.session_state.history = []  # list of dicts: {hostname, target, time}

st.title("Cloud-Native Auto Scaling — Live Dashboard")
st.caption(f"Backend URL: `{BACKEND_URL}`")

col1, col2 = st.columns([1, 3])

with col1:
    st.subheader("Controls")
    fetch_now = st.button("Fetch once")
    auto_refresh = st.toggle("Auto-refresh (every 2s)")
    clear_history = st.button("Clear history")
    if clear_history:
        st.session_state.history = []


def fetch_backend():
    try:
        resp = requests.get(f"{BACKEND_URL}/", timeout=3)
        resp.raise_for_status()
        data = resp.json()
        st.session_state.history.append(
            {
                "hostname": data.get("hostname", "unknown"),
                "deployment_target": data.get("deployment_target", "unknown"),
                "request_count_on_instance": data.get(
                    "request_count_on_this_instance", 0
                ),
                "fetched_at": time.strftime("%H:%M:%S"),
            }
        )
        return data, None
    except requests.exceptions.RequestException as e:
        return None, str(e)


if fetch_now or auto_refresh:
    data, error = fetch_backend()

    with col1:
        if error:
            st.error(f"Could not reach backend: {error}")
        elif data:
            st.success("Backend reachable")
            st.metric("Hostname served by", data.get("hostname", "unknown"))
            st.metric("Deployment target", data.get("deployment_target", "unknown"))
            st.metric("Uptime (s)", data.get("uptime_seconds", 0))

with col2:
    st.subheader("Which backend instance served each request")
    if st.session_state.history:
        df = pd.DataFrame(st.session_state.history)

        # Bar chart: how many requests each unique hostname has served.
        # If your ASG/ECS service has multiple healthy instances/tasks,
        # you should see traffic spread across more than one hostname here.
        counts = Counter(df["hostname"])
        counts_df = pd.DataFrame(
            {"hostname": list(counts.keys()), "requests_seen": list(counts.values())}
        ).sort_values("requests_seen", ascending=False)

        st.bar_chart(counts_df.set_index("hostname"))

        st.write(f"Unique backend instances/hosts seen: **{len(counts)}**")
        st.dataframe(df.tail(20).iloc[::-1], use_container_width=True)
    else:
        st.info(
            "No data yet — click 'Fetch once' or turn on auto-refresh. "
            "Run a load test (Phase 8) while this is open to watch requests "
            "spread across multiple instances as the Auto Scaling Group "
            "or ECS service scales out."
        )

if auto_refresh:
    time.sleep(2)
    st.rerun()
