package org.apidb.apicommon.datasetInjector;

/**
 * @author Jerric
 * @modified Jan 6, 2006
 */
public class UnexpectedException extends RuntimeException {

    public static String modelName;

    /**
     * 
     */
    private static final long serialVersionUID = 442861349675564533L;

    public UnexpectedException() {
        super();
    }

    public UnexpectedException(String message) {
        super(message);
    }

    public UnexpectedException(Throwable cause) {
        super(cause);
    }

    public UnexpectedException(String msg, Throwable cause) {
        super(msg, cause);
    }
}
