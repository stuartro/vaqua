/*
 * Copyright (c) 2015 Alan Snyder.
 * All rights reserved.
 *
 * You may not use, copy or modify this file, except in compliance with the license agreement. For details see
 * accompanying license terms.
 */

package org.violetlib.aqua;

import java.awt.*;
import java.awt.event.HierarchyEvent;
import java.awt.event.HierarchyListener;
import java.awt.event.WindowAdapter;
import java.awt.event.WindowEvent;
import javax.swing.*;

/**
 * Support for displaying windows as sheets.
 */
public class AquaSheetSupport {

    /**
     * Display a window as a sheet, if possible. A sheet is dismissed when the window is hidden or disposed.
     * <p>
     * The behavior of a sheet is similar to a document modal dialog in that it prevents user interaction with the
     * existing windows in the hierarchy of the owner. Unlike {@code setVisible(true)} on a model dialog, however, this
     * method does not block waiting for the sheet to be dismissed.
     *
     * @param w the window. The window must have a visible owner. The window must not be visible. If the window is a
     * dialog, its modality will be set to modeless.
     * @param closeHandler If not null, this object will be invoked when the sheet is dismissed.
     * @throws UnsupportedOperationException if the window could not be displayed as a sheet.
     */
    public static void displayAsSheet(Window w, Runnable closeHandler) throws UnsupportedOperationException {
        Window owner = w.getOwner();
        if (owner == null) {
            throw new UnsupportedOperationException("Unable to display as sheet: no owner window");
        }

        if (!owner.isVisible()) {
            throw new UnsupportedOperationException("Unable to display as sheet: owner window is not visible");
        }

        if (w.isVisible()) {
            throw new UnsupportedOperationException("Unable to display as sheet: the window must not be visible");
        }

        if (w instanceof Dialog) {
            Dialog d = (Dialog) w;
            d.setModalityType(Dialog.ModalityType.MODELESS);
        }

        AquaUtils.ensureWindowPeer(w);

        // The window should not be decorated. If it is decorated, the initial painting will go in the wrong place.
        // Unfortunately, Java is very picky about when setUndecorated() can be called. So we just munge the style bits
        // directly.

        boolean needToUndecorate = false;
        if (w instanceof Dialog) {
            Dialog d = (Dialog) w;
            if (!d.isUndecorated()) {
                needToUndecorate = true;
            }
        } else if (w instanceof Frame) {
            Frame fr = (Frame) w;
            if (!fr.isUndecorated()) {
                needToUndecorate = true;
            }
        }

        int oldTop = 0;
        if (needToUndecorate) {
            //syslog("About to reset title window style");
            oldTop = AquaUtils.unsetTitledWindowStyle(w);
        }

        JRootPane rp = null;
        if (w instanceof RootPaneContainer) {
            RootPaneContainer rpc = (RootPaneContainer) w;
            rp = rpc.getRootPane();
        }

        Object oldBackgroundStyle = null;

        if (rp != null) {
            //syslog("About to set vibrant style");
            oldBackgroundStyle = rp.getClientProperty(AquaVibrantSupport.BACKGROUND_STYLE_KEY);
            rp.putClientProperty(AquaVibrantSupport.BACKGROUND_STYLE_KEY, "vibrantSheet");
            w.validate();

            //syslog("About to paint sheet");
            AquaUtils.paintImmediately(rp);
        }

        // It would be better to dismiss a sheet by calling endSheet. Using endSheet supports deferred and critical
        // sheets. However, existing dialogs all dismiss themselves by calling setVisible(false) and we have no way to
        // alter what that does.

        SheetCloser closer = new SheetCloser(w, closeHandler, oldBackgroundStyle);
        int result;
        if ("true".equals(System.getProperty("VAqua.injectSheetDisplayFailure"))) {
            // inject failure for testing
            System.err.println("Injected failure to display sheet");
            result = -1;
        } else {
            result = nativeDisplayAsSheet(w);
        }

        if (result != 0) {
            closer.dispose();
            if (oldTop > 0) {
                AquaUtils.restoreTitledWindowStyle(w, oldTop);
                AquaUtils.syncAWTView(w);
            }
            throw new UnsupportedOperationException("Unable to display as sheet");
        }

        w.setVisible(true); // cause the lightweight components to be painted -- this method blocks on a modal dialog
    }

    /**
     * A sheet closer performs the necessary operations when a sheet is dismissed.
     */
    private static class SheetCloser extends WindowAdapter implements HierarchyListener {
        private final Window w;
        private final Runnable closeHandler;
        private final Object oldBackgroundStyle;
        private boolean hasClosed = false;

        public SheetCloser(Window w, Runnable closeHandler, Object oldBackgroundStyle) {
            this.w = w;
            this.closeHandler = closeHandler;
            this.oldBackgroundStyle = oldBackgroundStyle;
            w.addWindowListener(this);
            w.addHierarchyListener(this);
        }

        @Override
        public void hierarchyChanged(HierarchyEvent e) {
            if (e.getChangeFlags() == HierarchyEvent.SHOWING_CHANGED && !w.isVisible()) {
                completed();
            }
        }

        @Override
        public void windowClosed(WindowEvent e) {
            completed();
        }

        private void completed() {
            if (!hasClosed) {
                hasClosed = true;
                dispose();
                if (closeHandler != null) {
                    closeHandler.run();
                }
            }
        }

        public void dispose() {
            w.removeWindowListener(this);
            w.removeHierarchyListener(this);
            if (w instanceof RootPaneContainer) {
                RootPaneContainer rpc = (RootPaneContainer) w;
                JRootPane rp = rpc.getRootPane();
                if (rp != null) {
                    rp.putClientProperty(AquaVibrantSupport.BACKGROUND_STYLE_KEY, oldBackgroundStyle);
                }
            }
        }
    }

    private static native int nativeDisplayAsSheet(Window w);
}
